-- =====================================================================
-- Quizzen – Moderation (App-Store-Richtlinie 1.2)
--
--  1) Nutzer blockieren (beidseitig wirksam, beendet Freundschaft)
--  2) Nutzer melden
--  3) Filter für anstößige Benutzernamen
--
-- Voraussetzung: 001–007
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Blockieren
-- ---------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

drop policy if exists "blocks_select_own" on public.user_blocks;
create policy "blocks_select_own" on public.user_blocks
  for select to authenticated using (blocker_id = auth.uid());
drop policy if exists "blocks_delete_own" on public.user_blocks;
create policy "blocks_delete_own" on public.user_blocks
  for delete to authenticated using (blocker_id = auth.uid());
-- Einfügen nur über block_user() (räumt gleichzeitig Freundschaft/Einladungen auf)

-- Gibt es eine Blockierung zwischen a und b (egal in welche Richtung)?
create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_blocks
     where (blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a)
  );
$$;

-- Alle Nutzer, die ich blockiert habe ODER die mich blockiert haben
-- (die App blendet sie in Suche, Vorschlägen und Einladungen aus)
create or replace function public.my_block_relations()
returns setof uuid
language sql stable security definer set search_path = public as $$
  select blocked_id from public.user_blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.user_blocks where blocked_id = auth.uid();
$$;

create or replace function public.block_user(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or p_user is null or p_user = auth.uid() then
    raise exception 'invalid_block';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id)
  values (auth.uid(), p_user)
  on conflict do nothing;

  -- Freundschaft / offene Anfragen beenden
  delete from public.friendships
   where (requester_id = auth.uid() and addressee_id = p_user)
      or (requester_id = p_user and addressee_id = auth.uid());

  -- Offene Duell-Einladungen zwischen beiden zurückziehen
  update public.matches set status = 'cancelled'
   where status = 'waiting'
     and ((host_id = auth.uid() and invited_id = p_user)
       or (host_id = p_user and invited_id = auth.uid()));
end;
$$;

create or replace function public.unblock_user(p_user uuid)
returns void
language sql security definer set search_path = public as $$
  delete from public.user_blocks where blocker_id = auth.uid() and blocked_id = p_user;
$$;

revoke all on function public.is_blocked(uuid, uuid)   from public, anon;
revoke all on function public.my_block_relations()      from public, anon;
revoke all on function public.block_user(uuid)          from public, anon;
revoke all on function public.unblock_user(uuid)        from public, anon;
grant execute on function public.is_blocked(uuid, uuid) to authenticated;
grant execute on function public.my_block_relations()    to authenticated;
grant execute on function public.block_user(uuid)        to authenticated;
grant execute on function public.unblock_user(uuid)      to authenticated;

-- Keine Freundschaftsanfragen zwischen blockierten Nutzern
create or replace function public._reject_blocked_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.is_blocked(new.requester_id, new.addressee_id) then
    raise exception 'blocked';
  end if;
  return new;
end;
$$;

drop trigger if exists friendships_block_check on public.friendships;
create trigger friendships_block_check
  before insert on public.friendships
  for each row execute function public._reject_blocked_friendship();

-- Keine Duell-Einladung an blockierte Nutzer
create or replace function public._reject_blocked_invite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.invited_id is not null and public.is_blocked(new.host_id, new.invited_id) then
    new.invited_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists matches_block_check on public.matches;
create trigger matches_block_check
  before insert or update of invited_id on public.matches
  for each row execute function public._reject_blocked_invite();

-- Beitreten per Code: blockierte Nutzer finden das Duell nicht
create or replace function public.join_match(p_code text)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches
   where invite_code = p_code and status = 'waiting'
   order by created_at desc limit 1;

  if v_match.id is null or public.is_blocked(v_match.host_id, auth.uid()) then
    raise exception 'code_not_found';
  end if;
  if v_match.host_id = auth.uid() then
    raise exception 'own_match';
  end if;
  if v_match.guest_id is not null and v_match.guest_id <> auth.uid() then
    raise exception 'match_full';
  end if;

  update public.matches set guest_id = auth.uid()
   where id = v_match.id and (guest_id is null or guest_id = auth.uid())
  returning * into v_match;

  if v_match.id is null then
    raise exception 'match_full';
  end if;
  return v_match;
end;
$$;


-- ---------------------------------------------------------------------
-- 2) Nutzer melden
-- ---------------------------------------------------------------------
create table if not exists public.user_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  reason      text not null,
  message     text,
  created_at  timestamptz not null default now(),
  status      text not null default 'open',
  constraint report_reason_len  check (char_length(reason) between 1 and 60),
  constraint report_message_len check (message is null or char_length(message) <= 1000),
  constraint no_self_report     check (reporter_id <> reported_id)
);

create index if not exists user_reports_open_idx on public.user_reports (created_at) where status = 'open';

alter table public.user_reports enable row level security;

-- Nur eigene Meldungen anlegen; lesen nur über das Supabase-Dashboard
drop policy if exists "user_reports_insert_own" on public.user_reports;
create policy "user_reports_insert_own" on public.user_reports
  for insert to authenticated with check (reporter_id = auth.uid());


-- ---------------------------------------------------------------------
-- 3) Benutzernamen-Filter (dieselbe Liste wie UsernameFilter.swift)
-- ---------------------------------------------------------------------
create or replace function public.is_offensive_username(p_name text)
returns boolean
language sql immutable set search_path = public as $$
  select regexp_replace(translate(lower(coalesce(p_name, '')), '0134578@$!|', 'oieastbasii'),
                        '[^a-zäöüß]', '', 'g')
         ~ ('(' || array_to_string(array[
           'fick', 'fotze', 'hurensohn', 'hure', 'nutte', 'wichser', 'wixxer', 'schlampe',
           'missgeburt', 'spast', 'behindert', 'schwuchtel', 'kanake', 'neger', 'nigger',
           'nigga', 'hitler', 'siegheil', 'arschloch', 'titten', 'kinderficker',
           'vergewaltig', 'fuck', 'shit', 'bitch', 'cunt', 'whore', 'slut', 'faggot',
           'retard', 'rapist', 'pedophil', 'paedophil', 'pädophil', 'porn', 'penis', 'vagina'
         ], '|') || ')');
$$;

create or replace function public._check_username()
returns trigger language plpgsql as $$
begin
  if new.username is not null and public.is_offensive_username(new.username) then
    raise exception 'username_not_allowed';
  end if;
  return new;
end;
$$;

drop trigger if exists accounts_username_check on public.accounts;
create trigger accounts_username_check
  before insert or update of username on public.accounts
  for each row execute function public._check_username();

-- Optional: bereits vorhandene problematische Namen anzeigen
-- select id, username from public.accounts where public.is_offensive_username(username);
