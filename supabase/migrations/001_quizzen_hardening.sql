-- =====================================================================
-- Quizzen – Härtung & Sync-Erweiterung
-- ENTWURF: Vor dem Ausführen im Supabase SQL-Editor prüfen!
--
-- Wichtig:
--  * Bestehende Policies mit ANDEREN Namen bleiben aktiv. Policies werden
--    per OR verknüpft – eine alte, zu offene Policy hebelt die neuen aus.
--    Vorher prüfen:  select * from pg_policies where schemaname = 'public';
--  * Spaltennamen/Typen sind aus dem Swift-Code abgeleitet. Falls deine
--    Tabellen abweichen, entsprechend anpassen.
--  * Am besten zuerst in einem Branch/Staging-Projekt testen.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) user_stats: Streak-Daten mitsynchronisieren (App sendet sie bereits;
--    ohne diese Spalten fällt die App automatisch auf den alten Sync zurück)
-- ---------------------------------------------------------------------
alter table public.user_stats
  add column if not exists last_played_date timestamptz,
  add column if not exists install_date     timestamptz;

-- Plausibilitäts-Checks (verhindern offensichtlich manipulierte Werte)
alter table public.user_stats
  drop constraint if exists user_stats_non_negative,
  add  constraint user_stats_non_negative check (
    total_answers >= 0 and correct_answers >= 0 and false_answers >= 0
    and quizzes_played >= 0 and current_streak >= 0 and best_streak >= 0
    and play_time >= 0
  ),
  drop constraint if exists user_stats_answers_consistent,
  add  constraint user_stats_answers_consistent check (
    correct_answers + false_answers = total_answers
    and current_streak <= best_streak
  );


-- ---------------------------------------------------------------------
-- 2) matches: Invite-Code eindeutig, solange das Match offen ist
--    (die App wiederholt bei Kollision mit neuem Code, Fehlercode 23505)
-- ---------------------------------------------------------------------
create unique index if not exists matches_open_invite_code_key
  on public.matches (invite_code)
  where guest_id is null;


-- ---------------------------------------------------------------------
-- 3) increment_match_score: Spalte NICHT mehr vom Client bestimmen lassen.
--    Der Server leitet aus auth.uid() ab, ob Host oder Gast punktet.
--    Signatur bleibt gleich, damit die App unverändert funktioniert.
-- ---------------------------------------------------------------------
create or replace function public.increment_match_score(match_id_input uuid, column_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set host_score  = host_score  + case when host_id  = auth.uid() then 1 else 0 end,
         guest_score = guest_score + case when guest_id = auth.uid() then 1 else 0 end
   where id = match_id_input
     and status = 'active'
     and auth.uid() in (host_id, guest_id);
  -- column_name wird bewusst ignoriert (früher potenziell manipulierbar)
end;
$$;

revoke all on function public.increment_match_score(uuid, text) from public, anon;
grant execute on function public.increment_match_score(uuid, text) to authenticated;

-- HINWEIS Anti-Cheat: Ob eine Antwort richtig ist, entscheidet weiterhin der
-- Client, weil die Fragen nur lokal im App-Bundle liegen. Echte Absicherung
-- geht nur, wenn die richtigen Antworten (bzw. deren Hash) serverseitig liegen
-- und eine RPC wie submit_answer(match_id, question_index, answer) prüft.


-- ---------------------------------------------------------------------
-- 4) Row Level Security
-- ---------------------------------------------------------------------

-- accounts: alle eingeloggten Nutzer dürfen lesen (Suche, Profile),
-- ändern nur den eigenen Datensatz
alter table public.accounts enable row level security;
drop policy if exists "accounts_select_authenticated" on public.accounts;
create policy "accounts_select_authenticated" on public.accounts
  for select to authenticated using (true);
drop policy if exists "accounts_update_own" on public.accounts;
create policy "accounts_update_own" on public.accounts
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- user_stats: lesen alle (Profile/Leaderboard), schreiben nur die eigene Zeile
alter table public.user_stats enable row level security;
drop policy if exists "user_stats_select_authenticated" on public.user_stats;
create policy "user_stats_select_authenticated" on public.user_stats
  for select to authenticated using (true);
drop policy if exists "user_stats_insert_own" on public.user_stats;
create policy "user_stats_insert_own" on public.user_stats
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "user_stats_update_own" on public.user_stats;
create policy "user_stats_update_own" on public.user_stats
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- quiz_attempts: nur eigene Versuche anlegen und lesen
alter table public.quiz_attempts enable row level security;
drop policy if exists "quiz_attempts_insert_own" on public.quiz_attempts;
create policy "quiz_attempts_insert_own" on public.quiz_attempts
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "quiz_attempts_select_own" on public.quiz_attempts;
create policy "quiz_attempts_select_own" on public.quiz_attempts
  for select to authenticated using (user_id = auth.uid());

-- friendships
alter table public.friendships enable row level security;
drop policy if exists "friendships_select_party" on public.friendships;
create policy "friendships_select_party" on public.friendships
  for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));
-- Anfragen nur im eigenen Namen und immer als 'pending'
drop policy if exists "friendships_insert_as_requester" on public.friendships;
create policy "friendships_insert_as_requester" on public.friendships
  for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending' and addressee_id <> auth.uid());
-- Annehmen darf NUR der Empfänger
drop policy if exists "friendships_update_addressee" on public.friendships;
create policy "friendships_update_addressee" on public.friendships
  for update to authenticated
  using (addressee_id = auth.uid())
  with check (addressee_id = auth.uid());
-- Ablehnen / zurückziehen / Freundschaft beenden: beide Seiten
drop policy if exists "friendships_delete_party" on public.friendships;
create policy "friendships_delete_party" on public.friendships
  for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- social_profiles: lesen alle, schreiben nur eigenes
alter table public.social_profiles enable row level security;
drop policy if exists "social_profiles_select_authenticated" on public.social_profiles;
create policy "social_profiles_select_authenticated" on public.social_profiles
  for select to authenticated using (true);
drop policy if exists "social_profiles_insert_own" on public.social_profiles;
create policy "social_profiles_insert_own" on public.social_profiles
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "social_profiles_update_own" on public.social_profiles;
create policy "social_profiles_update_own" on public.social_profiles
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- matches
alter table public.matches enable row level security;
-- Teilnehmer sehen ihr Match; offene Matches sind per Code auffindbar
drop policy if exists "matches_select" on public.matches;
create policy "matches_select" on public.matches
  for select to authenticated
  using (auth.uid() in (host_id, guest_id) or guest_id is null);
drop policy if exists "matches_insert_host" on public.matches;
create policy "matches_insert_host" on public.matches
  for insert to authenticated with check (host_id = auth.uid());
-- Host darf sein Match steuern (Start, nächste Frage)
drop policy if exists "matches_update_host" on public.matches;
create policy "matches_update_host" on public.matches
  for update to authenticated
  using (host_id = auth.uid()) with check (host_id = auth.uid());
-- Gast darf nur einem offenen Match beitreten (und sich selbst eintragen)
drop policy if exists "matches_update_join" on public.matches;
create policy "matches_update_join" on public.matches
  for update to authenticated
  using (guest_id is null and host_id <> auth.uid())
  with check (guest_id = auth.uid());
-- Achtung: Die Join-Policy erlaubt dem Gast im selben Update theoretisch auch,
-- andere Spalten (z. B. Scores) zu setzen. Sauberer wäre eine RPC
-- join_match(code) mit security definer, die nur guest_id setzt.

-- Storage: Avatare nur im eigenen Ordner <user_id>/... schreiben
drop policy if exists "avatars_write_own_folder" on storage.objects;
create policy "avatars_write_own_folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_update_own_folder" on storage.objects;
create policy "avatars_update_own_folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
