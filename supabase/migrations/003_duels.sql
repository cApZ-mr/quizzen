-- =====================================================================
-- Quizzen – Duell-Modus: serverseitige Spiellogik
-- ENTWURF: Vor dem Ausführen im Supabase SQL-Editor prüfen!
--
-- Prinzip: Die Datenbank ist die einzige Wahrheit. Alle Schreibzugriffe
-- laufen über die Funktionen unten (security definer), die Teilnahme,
-- Reihenfolge und Zeitlimit prüfen. Die App liest den Zustand gebündelt
-- über match_state() und bekommt Änderungen per Realtime + Polling.
--
-- Status eines Matches: waiting → active → finished | cancelled
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Tabellen erweitern / anlegen
-- ---------------------------------------------------------------------
alter table public.matches
  add column if not exists question_started_at timestamptz,
  add column if not exists question_duration   int not null default 20,
  add column if not exists finished_at         timestamptz,
  add column if not exists left_by             uuid;

alter table public.matches alter column status set default 'waiting';
-- Alle vier Status zulassen (siehe auch 004_match_status.sql)
alter table public.matches drop constraint if exists matches_status_check;
alter table public.matches
  add constraint matches_status_check
  check (status in ('waiting', 'active', 'finished', 'cancelled'));
update public.matches set status = 'waiting' where status is null;

create table if not exists public.match_answers (
  id             uuid primary key default gen_random_uuid(),
  match_id       uuid not null references public.matches(id) on delete cascade,
  user_id        uuid not null,
  question_index int  not null,
  answer         text,                -- null = Zeit abgelaufen
  is_correct     boolean not null default false,
  answered_at    timestamptz not null default now()
);

alter table public.match_answers alter column answer drop not null;
alter table public.match_answers add column if not exists answered_at timestamptz not null default now();

-- Pro Spieler und Frage genau eine Antwort
create unique index if not exists match_answers_once_idx
  on public.match_answers (match_id, user_id, question_index);


-- ---------------------------------------------------------------------
-- 2) RLS: Lesen nur für Teilnehmende, Schreiben nur über Funktionen
-- ---------------------------------------------------------------------
alter table public.match_answers enable row level security;

drop policy if exists "match_answers_select_participants" on public.match_answers;
create policy "match_answers_select_participants" on public.match_answers
  for select to authenticated
  using (exists (select 1 from public.matches m
                  where m.id = match_id and auth.uid() in (m.host_id, m.guest_id)));
-- Keine insert/update/delete-Policies: das geht nur über submit_answer().


-- ---------------------------------------------------------------------
-- 3) Hilfsfunktion: Punkte aus den Antworten neu berechnen
-- ---------------------------------------------------------------------
create or replace function public._recalc_match_scores(p_match_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.matches m
     set host_score  = (select count(*) from public.match_answers a
                         where a.match_id = m.id and a.user_id = m.host_id and a.is_correct),
         guest_score = (select count(*) from public.match_answers a
                         where a.match_id = m.id and a.user_id = m.guest_id and a.is_correct)
   where m.id = p_match_id;
$$;


-- ---------------------------------------------------------------------
-- 4) Beitreten per Code (atomar, kein doppelter Gast möglich)
-- ---------------------------------------------------------------------
create or replace function public.join_match(p_code text)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches
   where invite_code = p_code and status = 'waiting'
   order by created_at desc limit 1;

  if v_match.id is null then
    raise exception 'code_not_found';
  end if;
  if v_match.host_id = auth.uid() then
    raise exception 'own_match';
  end if;
  if v_match.guest_id is not null and v_match.guest_id <> auth.uid() then
    raise exception 'match_full';
  end if;

  update public.matches set guest_id = auth.uid()
   where id = v_match.id and (guest_id is null or guest_id = auth.uid())
  returning * into v_match;

  if v_match.id is null then
    raise exception 'match_full';
  end if;
  return v_match;
end;
$$;


-- ---------------------------------------------------------------------
-- 5) Spiel starten (nur Host, nur mit Gast)
-- ---------------------------------------------------------------------
create or replace function public.start_match(p_match_id uuid, p_quiz_id text, p_question_order int[])
returns public.matches
language plpgsql security definer set search_path = public as $$
declare
  v_match public.matches;
begin
  update public.matches
     set quiz_id = p_quiz_id,
         question_order = p_question_order,
         status = 'active',
         current_question_index = 0,
         question_started_at = now(),
         host_score = 0,
         guest_score = 0
   where id = p_match_id
     and host_id = auth.uid()
     and guest_id is not null
     and status = 'waiting'
     and coalesce(array_length(p_question_order, 1), 0) between 1 and 30
  returning * into v_match;

  if v_match.id is null then
    raise exception 'cannot_start';
  end if;
  delete from public.match_answers where match_id = p_match_id;
  return v_match;
end;
$$;


-- ---------------------------------------------------------------------
-- 6) Antwort abgeben (nur aktuelle Frage, nur einmal, nur in der Zeit)
-- ---------------------------------------------------------------------
create or replace function public.submit_answer(
  p_match_id uuid, p_question_index int, p_answer text, p_is_correct boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if v_match.id is null or auth.uid() not in (v_match.host_id, v_match.guest_id) then
    raise exception 'not_participant';
  end if;
  if v_match.status <> 'active' or v_match.current_question_index <> p_question_index then
    return;  -- veraltet: still ignorieren
  end if;
  -- 2 s Kulanz für Netzwerk-Latenz; danach zählt die Antwort als falsch
  if now() > v_match.question_started_at + make_interval(secs => v_match.question_duration + 2) then
    p_is_correct := false;
  end if;

  insert into public.match_answers (match_id, user_id, question_index, answer, is_correct)
  values (p_match_id, auth.uid(), p_question_index, p_answer, coalesce(p_is_correct, false))
  on conflict (match_id, user_id, question_index) do nothing;

  perform public._recalc_match_scores(p_match_id);
end;
$$;


-- ---------------------------------------------------------------------
-- 7) Weiter zur nächsten Frage – idempotent, darf jede Seite aufrufen
--    Erlaubt, wenn beide geantwortet haben ODER die Zeit (+3 s) um ist.
-- ---------------------------------------------------------------------
create or replace function public.advance_match(p_match_id uuid, p_from_index int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_match   public.matches;
  v_answers int;
  v_total   int;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if v_match.id is null or auth.uid() not in (v_match.host_id, v_match.guest_id) then
    raise exception 'not_participant';
  end if;
  if v_match.status <> 'active' or v_match.current_question_index <> p_from_index then
    return;  -- schon weitergeschaltet
  end if;

  select count(*) into v_answers from public.match_answers
   where match_id = p_match_id and question_index = p_from_index;

  if v_answers < 2
     and now() < v_match.question_started_at + make_interval(secs => v_match.question_duration + 3) then
    return;  -- noch zu früh
  end if;

  v_total := coalesce(array_length(v_match.question_order, 1), 0);

  if p_from_index + 1 >= v_total then
    update public.matches set status = 'finished', finished_at = now() where id = p_match_id;
  else
    update public.matches
       set current_question_index = p_from_index + 1,
           question_started_at = now()
     where id = p_match_id;
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- 8) Match verlassen / aufgeben
-- ---------------------------------------------------------------------
create or replace function public.leave_match(p_match_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.matches
     set status = 'cancelled', left_by = auth.uid(), finished_at = now()
   where id = p_match_id
     and auth.uid() in (host_id, guest_id)
     and status in ('waiting', 'active');
end;
$$;


-- ---------------------------------------------------------------------
-- 9) Gebündelter Zustand für die App (inkl. Server-Zeit für den Timer)
--    Die Antwort des Gegners auf die LAUFENDE Frage wird erst sichtbar,
--    wenn man selbst geantwortet hat (kein Abschauen über die API).
-- ---------------------------------------------------------------------
create or replace function public.match_state(p_match_id uuid)
returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_match public.matches;
  v_i_answered boolean;
begin
  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null or auth.uid() not in (v_match.host_id, coalesce(v_match.guest_id, v_match.host_id)) then
    raise exception 'not_participant';
  end if;

  select exists (select 1 from public.match_answers
                  where match_id = p_match_id and user_id = auth.uid()
                    and question_index = v_match.current_question_index)
    into v_i_answered;

  return json_build_object(
    'match', row_to_json(v_match),
    'server_time', now(),
    'answers', coalesce((
      select json_agg(json_build_object(
               'user_id', a.user_id,
               'question_index', a.question_index,
               'answer', case
                           when a.user_id <> auth.uid()
                            and a.question_index = v_match.current_question_index
                            and v_match.status = 'active'
                            and not v_i_answered
                           then null else a.answer end,
               'is_correct', case
                           when a.user_id <> auth.uid()
                            and a.question_index = v_match.current_question_index
                            and v_match.status = 'active'
                            and not v_i_answered
                           then false else a.is_correct end,
               'answered_at', a.answered_at)
             order by a.question_index, a.answered_at)
        from public.match_answers a where a.match_id = p_match_id), '[]'::json)
  );
end;
$$;


-- ---------------------------------------------------------------------
-- 10) Rechte
-- ---------------------------------------------------------------------
revoke all on function public._recalc_match_scores(uuid) from public, anon, authenticated;
revoke all on function public.join_match(text)                            from public, anon;
revoke all on function public.start_match(uuid, text, int[])              from public, anon;
revoke all on function public.submit_answer(uuid, int, text, boolean)     from public, anon;
revoke all on function public.advance_match(uuid, int)                    from public, anon;
revoke all on function public.leave_match(uuid)                           from public, anon;
revoke all on function public.match_state(uuid)                           from public, anon;
grant execute on function public.join_match(text)                         to authenticated;
grant execute on function public.start_match(uuid, text, int[])           to authenticated;
grant execute on function public.submit_answer(uuid, int, text, boolean)  to authenticated;
grant execute on function public.advance_match(uuid, int)                 to authenticated;
grant execute on function public.leave_match(uuid)                        to authenticated;
grant execute on function public.match_state(uuid)                        to authenticated;


-- ---------------------------------------------------------------------
-- 11) Realtime: Änderungen an matches/match_answers live verschicken
--     (die App pollt zusätzlich, funktioniert also auch ohne)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and tablename = 'matches') then
    alter publication supabase_realtime add table public.matches;
  end if;
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and tablename = 'match_answers') then
    alter publication supabase_realtime add table public.match_answers;
  end if;
end $$;

-- Hinweis zu 001: Die dort entworfene Policy "matches_update_join" und die
-- RPC increment_match_score werden durch join_match()/submit_answer() ersetzt
-- und können entfernt werden:
--   drop policy if exists "matches_update_join" on public.matches;
--   drop function if exists public.increment_match_score(uuid, text);
