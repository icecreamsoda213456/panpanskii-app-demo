-- READ-ONLY verification for Panpanskii two-user security hardening.
-- This file does not insert, update, delete, alter, grant, revoke, or execute
-- any application RPC.

-- 1. Exactly two approved slots should be present.
select
  slot,
  user_id,
  created_at,
  updated_at
from public.panpanskii_approved_users
order by slot;

select
  count(*) as approved_user_count,
  count(*) = 2 as exactly_two_users
from public.panpanskii_approved_users;

-- 2. Review every Supabase Auth account. Any row without an approved slot is
-- an unrelated account and must not be able to access private app data.
select
  users.id,
  users.email,
  approved.slot,
  approved.user_id is not null as is_approved,
  users.created_at,
  users.last_sign_in_at
from auth.users users
left join public.panpanskii_approved_users approved
  on approved.user_id = users.id
order by users.created_at;

-- 3. Verify the PostgREST pre-request guard.
select
  roles.rolname,
  settings.setdatabase,
  config_value
from pg_db_role_setting settings
join pg_roles roles
  on roles.oid = settings.setrole
cross join lateral unnest(settings.setconfig)
  as config_entry(config_value)
where roles.rolname = 'authenticator'
  and config_value like 'pgrst.db_pre_request=%'
order by settings.setdatabase;

-- 4. Every ordinary/partitioned public table should have RLS enabled and both
-- restrictive Panpanskii policies.
select
  classes.relname as table_name,
  classes.relrowsecurity as rls_enabled,
  coalesce(
    bool_or(policies.policyname = 'panpanskii_deny_anon'),
    false
  ) as denies_anon,
  coalesce(
    bool_or(policies.policyname = 'panpanskii_approved_users_only'),
    false
  ) as restricts_authenticated
from pg_class classes
join pg_namespace namespaces
  on namespaces.oid = classes.relnamespace
left join pg_policies policies
  on policies.schemaname = namespaces.nspname
 and policies.tablename = classes.relname
where namespaces.nspname = 'public'
  and classes.relkind in ('r', 'p')
group by classes.relname, classes.relrowsecurity
order by classes.relname;

-- 5. Review all public policies. Original feature policies should still exist;
-- the Panpanskii policies should appear as RESTRICTIVE.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, permissive, policyname;

-- 6. Storage object policies must include both restrictive policies.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by permissive, policyname;

-- 7. Inventory SECURITY DEFINER RPCs still executable by authenticated users.
-- The PostgREST pre-request guard protects calls made through Supabase RPC.
select
  namespaces.nspname as function_schema,
  procedures.proname as function_name,
  pg_get_function_identity_arguments(procedures.oid) as arguments,
  has_function_privilege(
    'authenticated',
    procedures.oid,
    'EXECUTE'
  ) as authenticated_can_execute
from pg_proc procedures
join pg_namespace namespaces
  on namespaces.oid = procedures.pronamespace
where namespaces.nspname = 'public'
  and procedures.prosecdef
order by procedures.proname, arguments;

-- 8. Review direct table privileges granted to API roles.
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema in ('public', 'storage')
  and grantee in ('anon', 'authenticated')
order by table_schema, table_name, grantee, privilege_type;
