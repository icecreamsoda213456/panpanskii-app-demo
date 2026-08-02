-- Panpanskii private two-user security hardening
--
-- Run this manually in Supabase SQL Editor only after replacing the two
-- REPLACE_WITH_* values below with the real Panda and Koala auth.users UUIDs.
--
-- This migration is non-destructive:
-- - no tables are dropped
-- - no rows are deleted
-- - existing feature policies and RPC implementations are preserved
-- - existing public-table policies remain authoritative for ownership rules
--
-- The migration adds:
-- 1. A two-slot server-side allowlist.
-- 2. Restrictive RLS policies that are ANDed with existing policies.
-- 3. A PostgREST pre-request check so SECURITY DEFINER RPCs cannot be called
--    by unrelated authenticated accounts.
-- 4. Restrictive Storage object policies.

begin;

-- ---------------------------------------------------------------------------
-- Approved-user allowlist
-- ---------------------------------------------------------------------------

create table if not exists public.panpanskii_approved_users (
  slot text primary key
    check (slot in ('panda', 'koala')),
  user_id uuid not null unique
    references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

comment on table public.panpanskii_approved_users is
  'The two Supabase users allowed to access the private Panpanskii app.';

alter table public.panpanskii_approved_users enable row level security;

-- Clients never need direct access to this table. The SECURITY DEFINER helper
-- below performs the membership check without exposing the allowlist.
revoke all on table public.panpanskii_approved_users
  from public, anon, authenticated;

do $configure_approved_users$
declare
  panda_user_text constant text := 'c369a415-7162-42ba-87ae-a1e515934d05';
  koala_user_text constant text := '45290b19-599d-4c37-b99a-0c1a9f17eb70';
  panda_user_id uuid;
  koala_user_id uuid;
begin
  if panda_user_text like 'REPLACE_WITH_%'
     or koala_user_text like 'REPLACE_WITH_%' then
    raise exception
      'Replace both approved-user UUID placeholders before running this migration.';
  end if;

  begin
    panda_user_id := panda_user_text::uuid;
    koala_user_id := koala_user_text::uuid;
  exception
    when invalid_text_representation then
      raise exception 'Both approved-user values must be valid Supabase user UUIDs.';
  end;

  if panda_user_id = koala_user_id then
    raise exception 'Panda and Koala must use two different Supabase user UUIDs.';
  end if;

  if not exists (select 1 from auth.users where id = panda_user_id) then
    raise exception 'The Panda UUID does not exist in auth.users.';
  end if;

  if not exists (select 1 from auth.users where id = koala_user_id) then
    raise exception 'The Koala UUID does not exist in auth.users.';
  end if;

  insert into public.panpanskii_approved_users (slot, user_id)
  values
    ('panda', panda_user_id),
    ('koala', koala_user_id)
  on conflict (slot) do update
  set user_id = excluded.user_id,
      updated_at = clock_timestamp();
end;
$configure_approved_users$;

create or replace function public.is_panpanskii_approved_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null
     and exists (
       select 1
       from public.panpanskii_approved_users approved
       where approved.user_id = auth.uid()
     );
$function$;

revoke all on function public.is_panpanskii_approved_user()
  from public, anon;
grant execute on function public.is_panpanskii_approved_user()
  to authenticated;

-- ---------------------------------------------------------------------------
-- PostgREST/RPC gate
-- ---------------------------------------------------------------------------

create or replace function public.panpanskii_enforce_approved_request()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.role() = 'authenticated'
     and not public.is_panpanskii_approved_user() then
    raise exception using
      errcode = '42501',
      message = 'This account is not approved for Panpanskii.';
  end if;
end;
$function$;

revoke all on function public.panpanskii_enforce_approved_request()
  from public;
grant execute on function public.panpanskii_enforce_approved_request()
  to anon, authenticated, service_role;

-- Do not silently replace an unrelated pre-request hook.
do $protect_existing_pre_request$
declare
  existing_pre_request text;
begin
  select split_part(config_value, '=', 2)
  into existing_pre_request
  from pg_db_role_setting settings
  join pg_roles roles
    on roles.oid = settings.setrole
  cross join lateral unnest(settings.setconfig)
    as config_entry(config_value)
  where roles.rolname = 'authenticator'
    and config_value like 'pgrst.db_pre_request=%'
  order by
    case
      when settings.setdatabase =
        (select oid from pg_database where datname = current_database())
      then 0
      else 1
    end
  limit 1;

  if existing_pre_request is not null
     and existing_pre_request <> 'public.panpanskii_enforce_approved_request' then
    raise exception
      'An existing PostgREST pre-request hook (%) is configured. Merge the Panpanskii check into that hook instead of replacing it.',
      existing_pre_request;
  end if;
end;
$protect_existing_pre_request$;

alter role authenticator
  set pgrst.db_pre_request = 'public.panpanskii_enforce_approved_request';

-- ---------------------------------------------------------------------------
-- Public schema RLS
-- ---------------------------------------------------------------------------

do $secure_public_tables$
declare
  target record;
begin
  for target in
    select
      namespaces.nspname as schema_name,
      classes.relname as table_name,
      classes.relrowsecurity as already_had_rls
    from pg_class classes
    join pg_namespace namespaces
      on namespaces.oid = classes.relnamespace
    where namespaces.nspname = 'public'
      and classes.relkind in ('r', 'p')
  loop
    execute format(
      'alter table %I.%I enable row level security',
      target.schema_name,
      target.table_name
    );

    -- A table that previously had RLS disabled relied on table grants alone.
    -- Preserve that behavior for the two approved users while removing access
    -- for everyone else. Existing RLS-enabled tables retain their own
    -- permissive ownership/feature policies.
    if not target.already_had_rls
       and target.table_name <> 'panpanskii_approved_users' then
      execute format(
        'drop policy if exists panpanskii_approved_users_baseline on %I.%I',
        target.schema_name,
        target.table_name
      );
      execute format(
        'create policy panpanskii_approved_users_baseline on %I.%I ' ||
        'as permissive for all to authenticated ' ||
        'using (public.is_panpanskii_approved_user()) ' ||
        'with check (public.is_panpanskii_approved_user())',
        target.schema_name,
        target.table_name
      );
    end if;

    execute format(
      'drop policy if exists panpanskii_deny_anon on %I.%I',
      target.schema_name,
      target.table_name
    );
    execute format(
      'create policy panpanskii_deny_anon on %I.%I ' ||
      'as restrictive for all to anon using (false) with check (false)',
      target.schema_name,
      target.table_name
    );

    execute format(
      'drop policy if exists panpanskii_approved_users_only on %I.%I',
      target.schema_name,
      target.table_name
    );
    execute format(
      'create policy panpanskii_approved_users_only on %I.%I ' ||
      'as restrictive for all to authenticated ' ||
      'using (public.is_panpanskii_approved_user()) ' ||
      'with check (public.is_panpanskii_approved_user())',
      target.schema_name,
      target.table_name
    );
  end loop;
end;
$secure_public_tables$;

-- ---------------------------------------------------------------------------
-- Supabase Storage RLS
-- ---------------------------------------------------------------------------

do $secure_storage_objects$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists panpanskii_deny_anon
      on storage.objects;
    create policy panpanskii_deny_anon
      on storage.objects
      as restrictive
      for all
      to anon
      using (false)
      with check (false);

    drop policy if exists panpanskii_approved_users_only
      on storage.objects;
    create policy panpanskii_approved_users_only
      on storage.objects
      as restrictive
      for all
      to authenticated
      using (public.is_panpanskii_approved_user())
      with check (public.is_panpanskii_approved_user());
  end if;
end;
$secure_storage_objects$;

notify pgrst, 'reload config';

commit;

-- Dashboard follow-up:
-- Supabase Dashboard -> Authentication -> Providers -> Email
-- Disable public sign-ups after confirming the two approved accounts exist.
