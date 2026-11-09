-- =====================================================================
-- Quizzen – alle Konten mit E-Mail „@quizzen-app.com“ vollständig löschen
--
-- SCHRITT 1 (optional, ändert nichts): Vorschau, welche Konten betroffen sind
--
--   select u.id, u.email, a.username
--     from auth.users u left join public.accounts a on a.id = u.id
--    where lower(u.email) like '%@quizzen-app.com';
--
-- SCHRITT 2: alles ab „begin;“ ausführen.
-- ⚠️ Nicht rückgängig zu machen. Bricht ohne Änderung ab, wenn kein Konto
--    gefunden wird. Profilbilder danach von Hand löschen:
--    Storage → avatars → Ordner mit den IDs aus dem Ergebnis.
-- =====================================================================

begin;

create temp table del_ids on commit drop as
  select u.id, u.email
    from auth.users u
   where lower(u.email) like '%@quizzen-app.com';

do $$
begin
  if (select count(*) from del_ids) = 0 then
    raise exception 'Abbruch: Kein Konto mit @quizzen-app.com gefunden. Nichts wurde gelöscht.';
  end if;
end $$;

-- Duelle, an denen sie beteiligt waren
delete from public.match_answers
 where match_id in (select id from public.matches
                     where host_id in (select id from del_ids)
                        or guest_id in (select id from del_ids));
delete from public.matches
 where host_id in (select id from del_ids) or guest_id in (select id from del_ids);

-- Soziales
delete from public.friendships
 where requester_id in (select id from del_ids) or addressee_id in (select id from del_ids);
delete from public.user_blocks
 where blocker_id in (select id from del_ids) or blocked_id in (select id from del_ids);
delete from public.user_reports
 where reporter_id in (select id from del_ids) or reported_id in (select id from del_ids);

-- Feedback und Fehlermeldungen
delete from public.feedback where user_id in (select id from del_ids);
delete from public.reports  where user_id in (select id from del_ids);

-- Spieldaten und Profil
delete from public.quiz_attempts      where user_id in (select id from del_ids);
delete from public.user_quiz_progress where user_id in (select id from del_ids);
delete from public.user_stats         where user_id in (select id from del_ids);
delete from public.social_profiles    where user_id in (select id from del_ids);

-- Konto und Login
delete from public.accounts where id in (select id from del_ids);
delete from auth.users      where id in (select id from del_ids);

-- Gelöschte Konten (IDs für den Storage-Ordner „avatars“)
select id, email from del_ids;

commit;
