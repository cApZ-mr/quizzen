-- =====================================================================
-- Quizzen – Freundesanzahl für fremde Profile
--
-- Seit 001 darf man nur die eigenen Freundschaften lesen. Die Anzahl der
-- Freunde einer anderen Person liefert deshalb diese Funktion (nur die Zahl,
-- keine Namen).
-- =====================================================================

create or replace function public.friend_count(p_user uuid)
returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.friendships
   where status = 'accepted'
     and (requester_id = p_user or addressee_id = p_user);
$$;

revoke all on function public.friend_count(uuid) from public, anon;
grant execute on function public.friend_count(uuid) to authenticated;
