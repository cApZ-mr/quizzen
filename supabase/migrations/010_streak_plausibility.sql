-- =====================================================================
-- Quizzen – Streaks plausibel halten
--
-- Eine Streak (aktuell oder Rekord) kann nicht mehr Tage haben, als das
-- Konto alt ist. Falsche Werte entstanden z. B., wenn auf einem Gerät noch
-- Statistiken eines früheren Kontos lagen und beim Abgleich übernommen wurden.
--
--  1) vorhandene Werte korrigieren
--  2) Trigger: neue Werte werden beim Speichern automatisch begrenzt
-- =====================================================================

-- Höchstmögliche Streak = Kalendertage seit Registrierung (inkl. heute)
create or replace function public._max_streak_days(p_user uuid)
returns int
language sql stable security definer set search_path = public as $$
  select coalesce(greatest((current_date - a.created_at::date) + 1, 1), 1)
    from public.accounts a
   where a.id = p_user;
$$;

revoke all on function public._max_streak_days(uuid) from public, anon, authenticated;

-- 1) Bestehende Daten korrigieren
update public.user_stats s
   set best_streak    = least(s.best_streak,    public._max_streak_days(s.user_id)),
       current_streak = least(s.current_streak, public._max_streak_days(s.user_id))
 where s.best_streak    > public._max_streak_days(s.user_id)
    or s.current_streak > public._max_streak_days(s.user_id);

-- 2) Beim Speichern begrenzen
create or replace function public._clamp_streaks()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_max int := public._max_streak_days(new.user_id);
begin
  if v_max is not null then
    new.current_streak := least(coalesce(new.current_streak, 0), v_max);
    new.best_streak    := least(coalesce(new.best_streak, 0), v_max);
  end if;
  if new.best_streak < new.current_streak then
    new.best_streak := new.current_streak;
  end if;
  return new;
end;
$$;

drop trigger if exists user_stats_clamp_streaks on public.user_stats;
create trigger user_stats_clamp_streaks
  before insert or update on public.user_stats
  for each row execute function public._clamp_streaks();

-- Kontrolle: Konten, deren Werte korrigiert wurden, haben jetzt
-- best_streak <= Tage seit Registrierung
-- select a.username, s.best_streak, (current_date - a.created_at::date) + 1 as max_tage
--   from public.user_stats s join public.accounts a on a.id = s.user_id
--  order by s.best_streak desc;
