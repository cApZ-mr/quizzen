-- =====================================================================
-- Quizzen – Fortschritt-Sync, faire Quiz-Bestenliste, Duell-Einladungen,
-- Plausibilitätsprüfung
--
-- Voraussetzung: 001–005 (insbesondere 001 für RLS auf accounts/user_stats)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Duell-Einladung an einen Freund
-- ---------------------------------------------------------------------
alter table public.matches add column if not exists invited_id uuid;
create index if not exists matches_invited_idx
  on public.matches (invited_id) where status = 'waiting';


-- ---------------------------------------------------------------------
-- 2) Fortschritt pro Quiz (bisher nur lokal auf dem Gerät)
-- ---------------------------------------------------------------------
create table if not exists public.user_quiz_progress (
  user_id       uuid   not null,
  quiz_key      text   not null,     -- lokaler Schlüssel, z. B. „Flaggen_Flags“
  quiz_id       text   not null,     -- Quiz-ID, z. B. „Flags“
  rounds_played int    not null default 0,
  answered_ids  text[] not null default '{}',
  correct_ids   text[] not null default '{}',
  false_ids     text[] not null default '{}',
  updated_at    timestamptz not null default now(),
  primary key (user_id, quiz_key),
  constraint progress_plausible check (
    rounds_played >= 0
    and cardinality(answered_ids) <= 5000
    and correct_ids <@ answered_ids
    and false_ids   <@ answered_ids
  )
);

create index if not exists user_quiz_progress_quiz_idx on public.user_quiz_progress (quiz_id);

alter table public.user_quiz_progress enable row level security;

drop policy if exists "progress_select_own" on public.user_quiz_progress;
create policy "progress_select_own" on public.user_quiz_progress
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "progress_insert_own" on public.user_quiz_progress;
create policy "progress_insert_own" on public.user_quiz_progress
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "progress_update_own" on public.user_quiz_progress;
create policy "progress_update_own" on public.user_quiz_progress
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "progress_delete_own" on public.user_quiz_progress;
create policy "progress_delete_own" on public.user_quiz_progress
  for delete to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------
-- 3) Faire Bestenliste pro Quiz: Anzahl gemeisterter (richtig
--    beantworteter, verschiedener) Fragen – unabhängig von der Rundenlänge
-- ---------------------------------------------------------------------
create or replace function public.leaderboard_quiz_mastery(
  p_quiz_id    text,
  user_ids     uuid[] default null,
  country_code text   default null,
  max_rows     int    default 50
)
returns table (
  user_id    uuid,
  username   text,
  avatar_url text,
  country    text,
  created_at timestamptz,
  value      bigint
)
language sql stable security definer set search_path = public as $$
  select a.id, a.username, a.avatar_url, a.country, a.created_at,
         sum(cardinality(p.correct_ids))::bigint as value
    from public.user_quiz_progress p
    join public.accounts a on a.id = p.user_id
   where p.quiz_id = p_quiz_id
     and (user_ids is null or p.user_id = any (user_ids))
     and (country_code is null or a.country = country_code)
   group by a.id, a.username, a.avatar_url, a.country, a.created_at
  having sum(cardinality(p.correct_ids)) > 0
   order by value desc, a.username
   limit least(greatest(max_rows, 1), 100);
$$;

revoke all on function public.leaderboard_quiz_mastery(text, uuid[], text, int) from public, anon;
grant execute on function public.leaderboard_quiz_mastery(text, uuid[], text, int) to authenticated;


-- ---------------------------------------------------------------------
-- 4) Plausibilität: unrealistische Sprünge in user_stats ablehnen
--    (Zurücksetzen auf kleinere Werte bleibt erlaubt)
-- ---------------------------------------------------------------------
create or replace function public._check_user_stats_jump()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and (
       new.total_answers  > old.total_answers  + 1000
    or new.quizzes_played > old.quizzes_played + 100
  ) then
    raise exception 'implausible_stats_jump';
  end if;
  if tg_op = 'INSERT' and new.total_answers > 20000 then
    raise exception 'implausible_stats_jump';
  end if;
  return new;
end;
$$;

drop trigger if exists user_stats_plausibility on public.user_stats;
create trigger user_stats_plausibility
  before insert or update on public.user_stats
  for each row execute function public._check_user_stats_jump();

-- Hinweis: Ob eine einzelne Antwort richtig ist, entscheidet weiterhin die App
-- (die Fragen liegen nur im App-Bundle). Vollständig fälschungssicher wird es
-- erst, wenn die Lösungen serverseitig liegen und dort geprüft werden.
