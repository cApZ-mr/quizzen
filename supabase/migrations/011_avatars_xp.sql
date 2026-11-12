-- =====================================================================
-- Quizzen – Profilbilder reparieren + XP-Bestenliste
--
-- Teil 1: Profilbilder – Lesen und Löschen im eigenen Ordner
--
-- Bisher gab es für den Bucket „avatars“ nur INSERT und UPDATE. Das
-- Überschreiben (upsert) braucht zusätzlich SELECT – deshalb ließ sich ein
-- Profilbild nach dem ersten Mal nicht mehr ändern. Die App lädt neue Bilder
-- jetzt unter eigenem Namen hoch und räumt alte auf; dafür braucht sie
-- SELECT (Ordner auflisten) und DELETE – jeweils nur im eigenen Ordner
-- <user_id>/…
--
-- Anzeigen der Bilder für andere läuft weiter über die öffentliche URL
-- (Bucket ist öffentlich) und ist davon nicht betroffen.
-- =====================================================================

drop policy if exists "avatars_select_own_folder" on storage.objects;
create policy "avatars_select_own_folder" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_delete_own_folder" on storage.objects;
create policy "avatars_delete_own_folder" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- UPDATE zusätzlich mit WITH CHECK absichern (Datei darf nicht in fremden Ordner verschoben werden)
drop policy if exists "avatars_update_own_folder" on storage.objects;
create policy "avatars_update_own_folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);


-- ---------------------------------------------------------------------
-- Teil 2: XP-Bestenliste
-- XP wie in der App (PlayerLevel): 10 XP pro richtiger Antwort,
-- 25 XP pro gespielter Runde. Als berechnete Spalte, damit sie nicht
-- manipuliert werden kann und immer zu den Statistiken passt.
-- ---------------------------------------------------------------------
alter table public.user_stats
  add column if not exists xp integer
  generated always as (correct_answers * 10 + quizzes_played * 25) stored;

create index if not exists user_stats_xp_idx on public.user_stats (xp desc);
