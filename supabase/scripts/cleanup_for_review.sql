-- =====================================================================
-- Quizzen – Datenbank für die App-Store-Prüfung aufräumen
--
-- Behält NUR die Konten „Tester 001“ und „Malte“ (inkl. Statistiken,
-- Fortschritt, Profil und ihrer gegenseitigen Freundschaft).
-- Löscht ALLES andere: übrige Konten (auch Login), Duelle, Meldungen,
-- Blockierungen, Feedback und Fehlermeldungen.
--
-- ⚠️ Nicht rückgängig zu machen. Läuft als eine Transaktion: Wenn nicht
--    genau zwei Konten gefunden werden, bricht es ab und ändert nichts.
-- =====================================================================

begin;

create temp table keep_ids on commit drop as
  select id from public.accounts where username in ('Tester 001', 'Malte');

do $$
begin
  if (select count(*) from keep_ids) <> 2 then
    raise exception 'Abbruch: Es wurden nicht genau 2 Konten gefunden (gefunden: %). Nichts wurde gelöscht.',
      (select count(*) from keep_ids);
  end if;
end $$;

-- Duelle (alle, sind nur Testdaten)
delete from public.match_answers;
delete from public.matches;

-- Freundschaften: nur die zwischen den beiden behaltenen Konten bleibt
delete from public.friendships
 where requester_id not in (select id from keep_ids)
    or addressee_id not in (select id from keep_ids);

-- Moderation, Feedback, Fehlermeldungen (alle)
delete from public.user_blocks;
delete from public.user_reports;
delete from public.reports;
delete from public.feedback;

-- Spieldaten der übrigen Konten
delete from public.quiz_attempts      where user_id not in (select id from keep_ids);
delete from public.user_quiz_progress where user_id not in (select id from keep_ids);
delete from public.user_stats         where user_id not in (select id from keep_ids);
delete from public.social_profiles    where user_id not in (select id from keep_ids);

-- Konten und Logins
delete from public.accounts where id not in (select id from keep_ids);
delete from auth.users      where id not in (select id from keep_ids);

-- Ergebnis zur Kontrolle
select
  (select count(*) from auth.users)       as logins,
  (select count(*) from public.accounts)   as konten,
  (select count(*) from public.friendships) as freundschaften,
  (select count(*) from public.matches)    as duelle,
  (select count(*) from public.user_stats) as statistiken;

commit;
