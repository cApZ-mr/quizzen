-- =====================================================================
-- Quizzen – Duell: Status "cancelled" erlauben (Aufgeben / Beenden)
--
-- Die bestehende Prüfregel matches_status_check ließ "cancelled" nicht zu,
-- dadurch schlug leave_match() mit Fehler 23514 fehl und aufgegebene
-- Duelle blieben ewig "active".
-- =====================================================================

alter table public.matches drop constraint if exists matches_status_check;
alter table public.matches
  add constraint matches_status_check
  check (status in ('waiting', 'active', 'finished', 'cancelled'));

-- Alte, liegengebliebene Duelle (älter als 2 Stunden) aufräumen
update public.matches
   set status = 'cancelled', finished_at = now()
 where status in ('waiting', 'active')
   and created_at < now() - interval '2 hours';
