-- =====================================================================
-- Quizzen – Duell: eigene Einstellungen
--
-- Der Host wählt Schwierigkeit bzw. eigene Einstellungen (Fragenzahl,
-- Zeit pro Frage, Antwortanzahl, Filter). Die Fragen-Reihenfolge liegt wie
-- bisher in question_order, die Zeit in question_duration. Die übrigen
-- Einstellungen (Antwortanzahl, Art der Falschantworten …) landen in
-- settings – beide Geräte erzeugen daraus mit demselben Startwert exakt
-- dieselben Antwortmöglichkeiten.
-- =====================================================================

alter table public.matches add column if not exists settings jsonb;

-- Alte Signatur ersetzen (neue Parameter haben Standardwerte)
drop function if exists public.start_match(uuid, text, int[]);

create or replace function public.start_match(
  p_match_id       uuid,
  p_quiz_id        text,
  p_question_order int[],
  p_duration       int   default 20,
  p_settings       jsonb default null
)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare
  v_match public.matches;
begin
  update public.matches
     set quiz_id = p_quiz_id,
         question_order = p_question_order,
         question_duration = least(greatest(coalesce(p_duration, 20), 5), 60),
         settings = p_settings,
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

revoke all on function public.start_match(uuid, text, int[], int, jsonb) from public, anon;
grant execute on function public.start_match(uuid, text, int[], int, jsonb) to authenticated;
