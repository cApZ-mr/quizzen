-- =====================================================================
-- Quizzen – öffentliche (nicht angemeldete) Lesezugriffe entfernen
--
-- Ältere Policies für die Rollen „anon“/„public“ ließen accounts,
-- user_stats und social_profiles ohne Login auslesen. Policies werden per
-- OR verknüpft, daher hebeln sie die Regeln aus 001 aus.
-- Diese Migration entfernt nur solche offenen Policies; die Regeln aus 001
-- („… to authenticated“) bleiben bestehen.
-- =====================================================================

-- Vorher ansehen (optional):
-- select tablename, policyname, roles, cmd from pg_policies
--  where schemaname = 'public' and tablename in ('accounts', 'user_stats', 'social_profiles');

do $$
declare
  r record;
begin
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and tablename in ('accounts', 'user_stats', 'social_profiles')
       and cmd in ('SELECT', 'ALL')
       and (roles @> array['public']::name[] or roles @> array['anon']::name[])
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    raise notice 'Entfernt: % auf %', r.policyname, r.tablename;
  end loop;
end $$;

-- Sicherheitsnetz: anon darf diese Tabellen grundsätzlich nicht lesen
revoke select on public.accounts, public.user_stats, public.social_profiles from anon;
