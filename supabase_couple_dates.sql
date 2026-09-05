-- Panpanskii Our Dates calendar
-- Paste this complete script into Supabase Dashboard -> SQL Editor -> New query.
-- This migration is non-destructive: it does not drop, truncate, or delete data.

begin;

create extension if not exists pgcrypto with schema extensions;

do $requirements$
begin
  if to_regprocedure('public.is_panpanskii_approved_user()') is null then
    raise exception
      'Run supabase_two_user_security_hardening.sql before this migration.';
  end if;
end;
$requirements$;

-- ---------------------------------------------------------------------------
-- Calendar data
-- ---------------------------------------------------------------------------

create table if not exists public.couple_dates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null,
  title text not null,
  notes text not null default '',
  category text not null default 'date',
  visibility text not null default 'shared',
  starts_at timestamptz not null,
  reminder_minutes integer default 60,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint couple_dates_username_length_check
    check (char_length(btrim(username)) between 1 and 80),
  constraint couple_dates_mascot_check
    check (mascot in ('panda', 'koala')),
  constraint couple_dates_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint couple_dates_notes_length_check
    check (char_length(notes) <= 1000),
  constraint couple_dates_category_check
    check (category in ('date', 'movie', 'game', 'food', 'other')),
  constraint couple_dates_visibility_check
    check (visibility in ('shared', 'personal')),
  constraint couple_dates_reminder_check
    check (reminder_minutes is null or reminder_minutes in (0, 10, 60, 1440))
);

create index if not exists couple_dates_starts_at_idx
  on public.couple_dates (starts_at);

create index if not exists couple_dates_user_starts_at_idx
  on public.couple_dates (user_id, starts_at);

create index if not exists couple_dates_visibility_starts_at_idx
  on public.couple_dates (visibility, starts_at);

create or replace function public.touch_couple_dates_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$function$;

drop trigger if exists touch_couple_dates_updated_at
  on public.couple_dates;
create trigger touch_couple_dates_updated_at
before update on public.couple_dates
for each row
execute function public.touch_couple_dates_updated_at();

revoke all on function public.touch_couple_dates_updated_at()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS: both approved users see shared plans; personal plans remain private.
-- Only the creator may edit or delete a plan.
-- ---------------------------------------------------------------------------

alter table public.couple_dates enable row level security;
alter table public.couple_dates replica identity full;

revoke all on table public.couple_dates from public, anon;
grant select, insert, update, delete on table public.couple_dates
  to authenticated;

drop policy if exists couple_dates_select_visible
  on public.couple_dates;
create policy couple_dates_select_visible
on public.couple_dates
for select
to authenticated
using (
  public.is_panpanskii_approved_user()
  and (visibility = 'shared' or user_id = auth.uid())
);

drop policy if exists couple_dates_insert_own
  on public.couple_dates;
create policy couple_dates_insert_own
on public.couple_dates
for insert
to authenticated
with check (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
);

drop policy if exists couple_dates_update_own
  on public.couple_dates;
create policy couple_dates_update_own
on public.couple_dates
for update
to authenticated
using (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
)
with check (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
);

drop policy if exists couple_dates_delete_own
  on public.couple_dates;
create policy couple_dates_delete_own
on public.couple_dates
for delete
to authenticated
using (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
);

drop policy if exists panpanskii_deny_anon
  on public.couple_dates;
create policy panpanskii_deny_anon
on public.couple_dates
as restrictive
for all
to anon
using (false)
with check (false);

drop policy if exists panpanskii_approved_users_only
  on public.couple_dates;
create policy panpanskii_approved_users_only
on public.couple_dates
as restrictive
for all
to authenticated
using (public.is_panpanskii_approved_user())
with check (public.is_panpanskii_approved_user());

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

do $realtime$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_dates'
  ) then
    alter publication supabase_realtime add table public.couple_dates;
  end if;
end;
$realtime$;

notify pgrst, 'reload schema';

commit;

-- A successful run returns one row with all values set to true.
select
  to_regclass('public.couple_dates') is not null as table_exists,
  coalesce((
    select relrowsecurity
    from pg_class
    where oid = 'public.couple_dates'::regclass
  ), false) as rls_enabled,
  (
    select count(*) = 6
    from pg_policies
    where schemaname = 'public'
      and tablename = 'couple_dates'
      and policyname in (
        'couple_dates_select_visible',
        'couple_dates_insert_own',
        'couple_dates_update_own',
        'couple_dates_delete_own',
        'panpanskii_deny_anon',
        'panpanskii_approved_users_only'
      )
  ) as policies_ready,
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_dates'
  ) as realtime_enabled;
