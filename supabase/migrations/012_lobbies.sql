-- =====================================================================
-- Quizzen – Duell-Modus wird zur Gruppen-Lobby (bis zu 10 Personen)
--
-- Ersetzt das 1-gegen-1-Duell (matches/match_answers, siehe 003–006) durch
-- eine Lobby, die über mehrere Runden bestehen bleibt: Host erstellt eine
-- Lobby, bis zu 9 weitere Personen treten per Code oder Einladung bei,
-- der Host startet eine Runde (ein beliebiges Quiz). Nach der letzten
-- Frage springt die Lobby automatisch zurück auf „offen" – alle landen
-- wieder im Warteraum und können (mit einem anderen Quiz) weiterspielen.
--
-- Prinzip wie beim bisherigen Duell: Die Datenbank ist die einzige
-- Wahrheit, alle Schreibzugriffe laufen über security-definer-Funktionen.
-- Die alten matches/match_answers-Tabellen bleiben unverändert liegen
-- (keine Altlasten-Migration nötig, die App nutzt sie nur nicht mehr).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Tabellen
-- ---------------------------------------------------------------------
create table if not exists public.lobbies (
  id                      uuid primary key default gen_random_uuid(),
  invite_code             text not null,
  host_id                 uuid not null,
  status                  text not null default 'open'
                            check (status in ('open', 'playing', 'closed')),
  quiz_id                 text,
  question_order          int[],
  round_number            int  not null default 0,
  current_question_index  int  not null default 0,
  question_started_at     timestamptz,
  question_duration       int  not null default 20,
  settings                jsonb,
  max_players             int  not null default 10 check (max_players between 2 and 10),
  round_finished_at       timestamptz,
  created_at              timestamptz not null default now(),
  closed_at               timestamptz
);

-- Code nur eindeutig, solange die Lobby offen/aktiv ist
create unique index if not exists lobbies_open_invite_code_idx
  on public.lobbies (invite_code) where status in ('open', 'playing');

create table if not exists public.lobby_members (
  lobby_id   uuid not null references public.lobbies(id) on delete cascade,
  user_id    uuid not null,
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (lobby_id, user_id)
);

create table if not exists public.lobby_answers (
  id             uuid primary key default gen_random_uuid(),
  lobby_id       uuid not null references public.lobbies(id) on delete cascade,
  round_number   int  not null,
  user_id        uuid not null,
  question_index int  not null,
  answer         text,                 -- null = Zeit abgelaufen
  is_correct     boolean not null default false,
  answered_at    timestamptz not null default now()
);

create unique index if not exists lobby_answers_once_idx
  on public.lobby_answers (lobby_id, round_number, user_id, question_index);

create table if not exists public.lobby_invites (
  id          uuid primary key default gen_random_uuid(),
  lobby_id    uuid not null references public.lobbies(id) on delete cascade,
  invited_id  uuid not null,
  invited_by  uuid not null,
  created_at  timestamptz not null default now()
);

create index if not exists lobby_invites_invited_idx on public.lobby_invites (invited_id, created_at desc);


-- ---------------------------------------------------------------------
-- 2) RLS: Lesen nur für Mitglieder (auch für Realtime nötig),
--    Schreiben ausschließlich über die Funktionen unten
-- ---------------------------------------------------------------------
alter table public.lobbies       enable row level security;
alter table public.lobby_members enable row level security;
alter table public.lobby_answers enable row level security;
alter table public.lobby_invites enable row level security;

drop policy if exists "lobbies_select_members" on public.lobbies;
create policy "lobbies_select_members" on public.lobbies
  for select to authenticated
  using (host_id = auth.uid()
         or exists (select 1 from public.lobby_members lm where lm.lobby_id = id and lm.user_id = auth.uid()));

drop policy if exists "lobby_members_select_fellow_members" on public.lobby_members;
create policy "lobby_members_select_fellow_members" on public.lobby_members
  for select to authenticated
  using (exists (select 1 from public.lobby_members lm2
                  where lm2.lobby_id = lobby_members.lobby_id and lm2.user_id = auth.uid()));

drop policy if exists "lobby_answers_select_members" on public.lobby_answers;
create policy "lobby_answers_select_members" on public.lobby_answers
  for select to authenticated
  using (exists (select 1 from public.lobby_members lm
                  where lm.lobby_id = lobby_answers.lobby_id and lm.user_id = auth.uid()));

drop policy if exists "lobby_invites_select_own" on public.lobby_invites;
create policy "lobby_invites_select_own" on public.lobby_invites
  for select to authenticated
  using (invited_id = auth.uid() or invited_by = auth.uid());
-- Keine insert/update/delete-Policies: alles läuft über die Funktionen.


-- ---------------------------------------------------------------------
-- 3) Lobby erstellen
-- ---------------------------------------------------------------------
create or replace function public.create_lobby()
returns public.lobbies
language plpgsql security definer set search_path = public as $$
declare
  v_lobby public.lobbies;
  v_code  text;
begin
  for _ in 1..5 loop
    v_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
    begin
      insert into public.lobbies (invite_code, host_id)
      values (v_code, auth.uid())
      returning * into v_lobby;
      exit;
    exception when unique_violation then
      v_lobby := null;
    end;
  end loop;

  if v_lobby.id is null then
    raise exception 'lobby_create_failed';
  end if;

  insert into public.lobby_members (lobby_id, user_id) values (v_lobby.id, auth.uid());
  return v_lobby;
end;
$$;


-- ---------------------------------------------------------------------
-- 4) Per Code beitreten (atomar; erneutes Beitreten nach „Verlassen“ erlaubt)
-- ---------------------------------------------------------------------
create or replace function public.join_lobby(p_code text)
returns public.lobbies
language plpgsql security definer set search_path = public as $$
declare
  v_lobby public.lobbies;
  v_active int;
begin
  select * into v_lobby from public.lobbies
   where invite_code = p_code and status in ('open', 'playing')
   order by created_at desc limit 1
   for update;

  if v_lobby.id is null then
    raise exception 'code_not_found';
  end if;

  if exists (select 1 from public.lobby_members
              where lobby_id = v_lobby.id and user_id = auth.uid() and left_at is null) then
    return v_lobby;  -- schon dabei (z. B. nach App-Neustart)
  end if;

  select count(*) into v_active from public.lobby_members
   where lobby_id = v_lobby.id and left_at is null;
  if v_active >= v_lobby.max_players then
    raise exception 'lobby_full';
  end if;

  insert into public.lobby_members (lobby_id, user_id)
  values (v_lobby.id, auth.uid())
  on conflict (lobby_id, user_id) do update set left_at = null, joined_at = now();

  return v_lobby;
end;
$$;


-- ---------------------------------------------------------------------
-- 5) Runde starten (nur Host, nur wenn offen, mind. 2 aktive Mitglieder)
-- ---------------------------------------------------------------------
create or replace function public.start_round(
  p_lobby_id       uuid,
  p_quiz_id        text,
  p_question_order int[],
  p_duration       int   default 20,
  p_settings       jsonb default null
)
returns public.lobbies
language plpgsql security definer set search_path = public as $$
declare
  v_lobby  public.lobbies;
  v_active int;
begin
  select * into v_lobby from public.lobbies where id = p_lobby_id for update;

  if v_lobby.id is null or v_lobby.host_id <> auth.uid() then
    raise exception 'not_host';
  end if;
  if v_lobby.status <> 'open' then
    raise exception 'round_already_running';
  end if;

  select count(*) into v_active from public.lobby_members
   where lobby_id = p_lobby_id and left_at is null;
  if v_active < 2 then
    raise exception 'not_enough_players';
  end if;
  if coalesce(array_length(p_question_order, 1), 0) not between 1 and 30 then
    raise exception 'invalid_question_order';
  end if;

  update public.lobbies
     set quiz_id = p_quiz_id,
         question_order = p_question_order,
         question_duration = least(greatest(coalesce(p_duration, 20), 5), 60),
         settings = p_settings,
         status = 'playing',
         round_number = round_number + 1,
         current_question_index = 0,
         question_started_at = now(),
         round_finished_at = null
   where id = p_lobby_id
  returning * into v_lobby;

  return v_lobby;
end;
$$;


-- ---------------------------------------------------------------------
-- 6) Antwort abgeben (nur aktuelle Frage/Runde, nur einmal, nur in der Zeit)
-- ---------------------------------------------------------------------
create or replace function public.submit_lobby_answer(
  p_lobby_id uuid, p_question_index int, p_answer text, p_is_correct boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lobby public.lobbies;
begin
  select * into v_lobby from public.lobbies where id = p_lobby_id for update;

  if v_lobby.id is null
     or not exists (select 1 from public.lobby_members
                      where lobby_id = p_lobby_id and user_id = auth.uid() and left_at is null) then
    raise exception 'not_participant';
  end if;
  if v_lobby.status <> 'playing' or v_lobby.current_question_index <> p_question_index then
    return;  -- veraltet: still ignorieren
  end if;
  -- 2 s Kulanz für Netzwerk-Latenz; danach zählt die Antwort als falsch
  if now() > v_lobby.question_started_at + make_interval(secs => v_lobby.question_duration + 2) then
    p_is_correct := false;
  end if;

  insert into public.lobby_answers (lobby_id, round_number, user_id, question_index, answer, is_correct)
  values (p_lobby_id, v_lobby.round_number, auth.uid(), p_question_index, p_answer, coalesce(p_is_correct, false))
  on conflict (lobby_id, round_number, user_id, question_index) do nothing;
end;
$$;


-- ---------------------------------------------------------------------
-- 7) Weiter zur nächsten Frage – idempotent, darf jedes Mitglied aufrufen.
--    Erlaubt, wenn alle aktiven Mitglieder geantwortet haben ODER die Zeit
--    (+3 s) um ist. Nach der letzten Frage geht die Lobby zurück auf „offen".
-- ---------------------------------------------------------------------
create or replace function public.advance_lobby(p_lobby_id uuid, p_from_index int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lobby   public.lobbies;
  v_active  int;
  v_answered int;
  v_total   int;
begin
  select * into v_lobby from public.lobbies where id = p_lobby_id for update;

  if v_lobby.id is null
     or not exists (select 1 from public.lobby_members
                      where lobby_id = p_lobby_id and user_id = auth.uid() and left_at is null) then
    raise exception 'not_participant';
  end if;
  if v_lobby.status <> 'playing' or v_lobby.current_question_index <> p_from_index then
    return;  -- schon weitergeschaltet
  end if;

  select count(*) into v_active from public.lobby_members
   where lobby_id = p_lobby_id and left_at is null;
  select count(distinct user_id) into v_answered from public.lobby_answers
   where lobby_id = p_lobby_id and round_number = v_lobby.round_number and question_index = p_from_index;

  if v_answered < v_active
     and now() < v_lobby.question_started_at + make_interval(secs => v_lobby.question_duration + 3) then
    return;  -- noch zu früh
  end if;

  v_total := coalesce(array_length(v_lobby.question_order, 1), 0);

  if p_from_index + 1 >= v_total then
    update public.lobbies
       set status = 'open', round_finished_at = now()
     where id = p_lobby_id;
  else
    update public.lobbies
       set current_question_index = p_from_index + 1,
           question_started_at = now()
     where id = p_lobby_id;
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- 8) Lobby verlassen. Verlässt der Host, übernimmt das am längsten
--    wartende verbleibende Mitglied; bleibt niemand übrig, wird
--    geschlossen.
-- ---------------------------------------------------------------------
create or replace function public.leave_lobby(p_lobby_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lobby public.lobbies;
  v_next  uuid;
begin
  select * into v_lobby from public.lobbies where id = p_lobby_id for update;
  if v_lobby.id is null then
    return;
  end if;

  update public.lobby_members
     set left_at = now()
   where lobby_id = p_lobby_id and user_id = auth.uid() and left_at is null;

  if v_lobby.host_id <> auth.uid() or v_lobby.status = 'closed' then
    return;
  end if;

  select user_id into v_next from public.lobby_members
   where lobby_id = p_lobby_id and left_at is null and user_id <> auth.uid()
   order by joined_at asc limit 1;

  if v_next is not null then
    update public.lobbies set host_id = v_next where id = p_lobby_id;
  else
    update public.lobbies set status = 'closed', closed_at = now() where id = p_lobby_id;
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- 9) Einen Freund einladen (reine Benachrichtigung, kein Türsteher –
--    beitreten geht wie immer per Code)
-- ---------------------------------------------------------------------
create or replace function public.invite_to_lobby(p_lobby_id uuid, p_invited_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.lobby_members
                   where lobby_id = p_lobby_id and user_id = auth.uid() and left_at is null) then
    raise exception 'not_participant';
  end if;
  insert into public.lobby_invites (lobby_id, invited_id, invited_by) values (p_lobby_id, p_invited_id, auth.uid());
end;
$$;

-- Offene Einladungen an mich (max. 30 Minuten alt), mit Lobby- und Absenderdaten
create or replace function public.my_lobby_invites()
returns table (
  lobby_id    uuid,
  invite_code text,
  status      text,
  invited_by  uuid,
  inviter_username text,
  inviter_avatar_url text,
  created_at  timestamptz
)
language sql stable security definer set search_path = public as $$
  select i.lobby_id, l.invite_code, l.status, i.invited_by, a.username, a.avatar_url, i.created_at
    from public.lobby_invites i
    join public.lobbies l on l.id = i.lobby_id
    join public.accounts a on a.id = i.invited_by
   where i.invited_id = auth.uid()
     and l.status in ('open', 'playing')
     and i.created_at > now() - interval '30 minutes'
   order by i.created_at desc;
$$;

-- Eigene offene Lobby (z. B. nach App-Neustart), max. 6 Stunden alt
create or replace function public.my_open_lobby()
returns public.lobbies
language sql stable security definer set search_path = public as $$
  select l.* from public.lobbies l
   where l.status in ('open', 'playing')
     and l.created_at > now() - interval '6 hours'
     and exists (select 1 from public.lobby_members lm
                  where lm.lobby_id = l.id and lm.user_id = auth.uid() and lm.left_at is null)
   order by l.created_at desc
   limit 1;
$$;


-- ---------------------------------------------------------------------
-- 10) Gebündelter Zustand für die App: Lobby, Mitglieder (mit Profil und
--     Gesamtpunktzahl über alle Runden) und Antworten der laufenden Runde.
--     Die Antwort anderer auf die LAUFENDE Frage wird erst sichtbar,
--     wenn man selbst geantwortet hat (kein Abschauen über die API).
-- ---------------------------------------------------------------------
create or replace function public.lobby_state(p_lobby_id uuid)
returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_lobby public.lobbies;
  v_i_answered boolean;
begin
  select * into v_lobby from public.lobbies where id = p_lobby_id;
  if v_lobby.id is null
     or not exists (select 1 from public.lobby_members where lobby_id = p_lobby_id and user_id = auth.uid()) then
    raise exception 'not_participant';
  end if;

  select exists (select 1 from public.lobby_answers
                  where lobby_id = p_lobby_id and user_id = auth.uid()
                    and round_number = v_lobby.round_number
                    and question_index = v_lobby.current_question_index)
    into v_i_answered;

  return json_build_object(
    'lobby', row_to_json(v_lobby),
    'server_time', now(),
    'members', coalesce((
      select json_agg(json_build_object(
               'user_id', m.user_id,
               'username', a.username,
               'avatar_url', a.avatar_url,
               'country', a.country,
               'joined_at', m.joined_at,
               'left_at', m.left_at,
               'is_host', m.user_id = v_lobby.host_id,
               'total_correct', coalesce((select count(*) from public.lobby_answers la
                                            where la.lobby_id = p_lobby_id and la.user_id = m.user_id
                                              and la.is_correct), 0))
             order by m.joined_at)
        from public.lobby_members m join public.accounts a on a.id = m.user_id
       where m.lobby_id = p_lobby_id), '[]'::json),
    'answers', coalesce((
      select json_agg(json_build_object(
               'user_id', la.user_id,
               'question_index', la.question_index,
               'answer', case
                           when la.user_id <> auth.uid()
                            and la.question_index = v_lobby.current_question_index
                            and v_lobby.status = 'playing'
                            and not v_i_answered
                           then null else la.answer end,
               'is_correct', case
                           when la.user_id <> auth.uid()
                            and la.question_index = v_lobby.current_question_index
                            and v_lobby.status = 'playing'
                            and not v_i_answered
                           then false else la.is_correct end,
               'answered_at', la.answered_at)
             order by la.question_index, la.answered_at)
        from public.lobby_answers la
       where la.lobby_id = p_lobby_id and la.round_number = v_lobby.round_number), '[]'::json)
  );
end;
$$;


-- ---------------------------------------------------------------------
-- 11) Rechte
-- ---------------------------------------------------------------------
revoke all on function public.create_lobby()                                       from public, anon;
revoke all on function public.join_lobby(text)                                      from public, anon;
revoke all on function public.start_round(uuid, text, int[], int, jsonb)            from public, anon;
revoke all on function public.submit_lobby_answer(uuid, int, text, boolean)         from public, anon;
revoke all on function public.advance_lobby(uuid, int)                              from public, anon;
revoke all on function public.leave_lobby(uuid)                                     from public, anon;
revoke all on function public.invite_to_lobby(uuid, uuid)                           from public, anon;
revoke all on function public.my_lobby_invites()                                    from public, anon;
revoke all on function public.my_open_lobby()                                       from public, anon;
revoke all on function public.lobby_state(uuid)                                     from public, anon;
grant execute on function public.create_lobby()                                     to authenticated;
grant execute on function public.join_lobby(text)                                   to authenticated;
grant execute on function public.start_round(uuid, text, int[], int, jsonb)         to authenticated;
grant execute on function public.submit_lobby_answer(uuid, int, text, boolean)      to authenticated;
grant execute on function public.advance_lobby(uuid, int)                           to authenticated;
grant execute on function public.leave_lobby(uuid)                                  to authenticated;
grant execute on function public.invite_to_lobby(uuid, uuid)                        to authenticated;
grant execute on function public.my_lobby_invites()                                 to authenticated;
grant execute on function public.my_open_lobby()                                    to authenticated;
grant execute on function public.lobby_state(uuid)                                  to authenticated;


-- ---------------------------------------------------------------------
-- 12) Realtime: Änderungen live verschicken (die App pollt zusätzlich
--     als Sicherheitsnetz, funktioniert also auch ohne)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and tablename = 'lobbies') then
    alter publication supabase_realtime add table public.lobbies;
  end if;
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and tablename = 'lobby_members') then
    alter publication supabase_realtime add table public.lobby_members;
  end if;
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and tablename = 'lobby_answers') then
    alter publication supabase_realtime add table public.lobby_answers;
  end if;
end $$;

-- Hinweis: Die alten Duell-Tabellen (matches, match_answers) und ihre
-- Funktionen (join_match, start_match, submit_answer, advance_match,
-- leave_match, match_state) werden von der App nicht mehr benutzt und
-- können bei Gelegenheit manuell aufgeräumt werden – hier bewusst nicht
-- automatisch gelöscht, falls noch irgendwo referenziert.
