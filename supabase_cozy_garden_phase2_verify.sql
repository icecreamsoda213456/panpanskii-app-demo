-- Cozy Garden Phase 2 verification only. This script does not modify data.

-- Required progression columns and the current shared garden row.
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'cozy_garden_state'
  and column_name in (
    'current_streak',
    'longest_streak',
    'total_harvests',
    'cycle_started_at',
    'last_completed_day',
    'last_harvested_at'
  )
order by column_name;

-- The Phase 2 plant check must allow every supported legacy and new plant.
select
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.cozy_garden_state'::regclass
  and contype = 'c'
  and pg_get_constraintdef(oid) like '%plant_type%';

select
  id,
  plant_type,
  growth,
  current_streak,
  longest_streak,
  total_harvests,
  cycle_started_at,
  last_completed_day,
  last_harvested_at,
  case
    when last_completed_day is null
      or last_completed_day < public._cozy_garden_effective_day() - 1
      or last_completed_day > public._cozy_garden_effective_day()
    then 0
    else current_streak
  end as effective_current_streak,
  growth between 0 and 100 as growth_is_valid
from public.cozy_garden_state
where id = 'main';

-- The server-owned day must use Asia/Manila with the 6:00 AM boundary.
select public._cozy_garden_effective_day() as server_effective_garden_day;

-- New Phase 2 table health and counts.
select 'cozy_garden_harvests' as table_name, count(*) as row_count
from public.cozy_garden_harvests
union all
select 'cozy_garden_unlocks', count(*)
from public.cozy_garden_unlocks
union all
select 'cozy_garden_bonus_events', count(*)
from public.cozy_garden_bonus_events;

-- RLS must be enabled for all shared progression tables.
select
  relname as table_name,
  relrowsecurity as rls_enabled
from pg_class
where oid in (
  'public.cozy_garden_state'::regclass,
  'public.cozy_garden_actions'::regclass,
  'public.cozy_garden_harvests'::regclass,
  'public.cozy_garden_unlocks'::regclass,
  'public.cozy_garden_bonus_events'::regclass
)
order by relname;

-- Only read policies should remain on the server-mutated shared garden tables.
-- This result should contain no insert, update, or delete policy for actions.
select
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'cozy_garden_state',
    'cozy_garden_actions',
    'cozy_garden_harvests',
    'cozy_garden_unlocks',
    'cozy_garden_bonus_events'
  )
order by tablename, policyname;

-- Required server RPCs.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'water_cozy_garden',
    'harvest_cozy_garden',
    'claim_daily_duo_garden_bonus',
    '_cozy_garden_effective_day'
  )
order by p.proname;

-- Authenticated callers should have execute permission only on public RPCs.
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where specific_schema = 'public'
  and routine_name in (
    'water_cozy_garden',
    'harvest_cozy_garden',
    'claim_daily_duo_garden_bonus'
  )
  and grantee in ('anon', 'authenticated', 'PUBLIC')
order by routine_name, grantee;

-- Realtime publication membership needed by the app.
select
  tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in (
    'cozy_garden_state',
    'cozy_garden_actions',
    'cozy_garden_unlocks',
    'cozy_garden_bonus_events'
  )
order by tablename;

-- Current collection state.
select
  unlock_key,
  unlock_type,
  unlock_source,
  unlocked_at,
  metadata
from public.cozy_garden_unlocks
order by unlock_type, unlocked_at, unlock_key;

select
  plant_type,
  harvested_at,
  final_growth,
  streak_at_harvest,
  harvested_by
from public.cozy_garden_harvests
order by harvested_at desc;

-- These result sets should be empty.
select
  day_key,
  event_type,
  count(*) as duplicate_count
from public.cozy_garden_bonus_events
group by day_key, event_type
having count(*) > 1;

select
  day_key,
  user_id,
  count(*) as duplicate_count
from public.cozy_garden_actions
group by day_key, user_id
having count(*) > 1;

select
  id,
  plant_type,
  growth
from public.cozy_garden_state
where growth < 0 or growth > 100;
