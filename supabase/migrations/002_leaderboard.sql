-- =====================================================================
-- Quizzen – Bestenliste nach Quiz-Kategorien
-- ENTWURF: Vor dem Ausführen im Supabase SQL-Editor prüfen!
--
-- Voraussetzung: 001_quizzen_hardening.sql (bzw. RLS-Policies, die allen
-- eingeloggten Nutzern SELECT auf accounts + user_stats erlauben – die
-- Kennzahl-Bestenlisten lesen user_stats direkt).
--
-- Punkte einer Kategorie = Summe des BESTEN Ergebnisses pro Quiz.
-- So bringt stumpfes Wiederholen desselben Quiz keine Punkte, und wer
-- mehr Quizze der Kategorie meistert, steht weiter oben.
-- Hinweis: quiz_attempts wird erst seit dem App-Update befüllt, ältere
-- Runden zählen hier also nicht.
-- =====================================================================

create index if not exists quiz_attempts_quiz_user_idx
  on public.quiz_attempts (quiz_id, user_id);

create or replace function public.leaderboard_quiz_scores(
  quiz_ids     text[],
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
language sql
stable
security definer
set search_path = public
as $$
  with best as (
    select qa.user_id, qa.quiz_id, max(qa.score) as best_score
      from public.quiz_attempts qa
     where qa.quiz_id = any (quiz_ids)
       and (user_ids is null or qa.user_id = any (user_ids))
     group by qa.user_id, qa.quiz_id
  )
  select a.id, a.username, a.avatar_url, a.country, a.created_at,
         sum(b.best_score)::bigint as value
    from best b
    join public.accounts a on a.id = b.user_id
   where (country_code is null or a.country = country_code)
   group by a.id, a.username, a.avatar_url, a.country, a.created_at
  having sum(b.best_score) > 0
   order by value desc, a.username
   limit least(greatest(max_rows, 1), 100);
$$;

revoke all on function public.leaderboard_quiz_scores(text[], uuid[], text, int) from public, anon;
grant execute on function public.leaderboard_quiz_scores(text[], uuid[], text, int) to authenticated;
