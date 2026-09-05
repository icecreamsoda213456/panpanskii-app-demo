-- Panpanskii Widget Notes
-- Hand-drawn notes that show up on the partner's Android home-screen widget.
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
-- Widget note data
-- ---------------------------------------------------------------------------

create table if not exists public.widget_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null,
  storage_path text not null,
  caption text,
  created_at timestamptz not null default clock_timestamp(),
  constraint widget_notes_username_length_check
    check (char_length(btrim(username)) between 1 and 80),
  constraint widget_notes_mascot_check
    check (mascot in ('panda', 'koala')),
  constraint widget_notes_storage_path_length_check
    check (char_length(btrim(storage_path)) between 1 and 300),
  constraint widget_notes_caption_length_check
    check (caption is null or char_length(btrim(caption)) <= 80)
);

create index if not exists widget_notes_created_at_idx
  on public.widget_notes (created_at desc);

create index if not exists widget_notes_user_created_at_idx
  on public.widget_notes (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS: both approved users can read every note (the widget shows the partner's
-- note); only the creator may delete their own notes. Notes are never edited.
-- ---------------------------------------------------------------------------

alter table public.widget_notes enable row level security;
alter table public.widget_notes replica identity full;

revoke all on table public.widget_notes from public, anon;
grant select, insert, delete on table public.widget_notes
  to authenticated;

drop policy if exists widget_notes_select_all
  on public.widget_notes;
create policy widget_notes_select_all
on public.widget_notes
for select
to authenticated
using (public.is_panpanskii_approved_user());

drop policy if exists widget_notes_insert_own
  on public.widget_notes;
create policy widget_notes_insert_own
on public.widget_notes
for insert
to authenticated
with check (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
);

drop policy if exists widget_notes_delete_own
  on public.widget_notes;
create policy widget_notes_delete_own
on public.widget_notes
for delete
to authenticated
using (
  public.is_panpanskii_approved_user()
  and user_id = auth.uid()
);

drop policy if exists panpanskii_deny_anon
  on public.widget_notes;
create policy panpanskii_deny_anon
on public.widget_notes
as restrictive
for all
to anon
using (false)
with check (false);

drop policy if exists panpanskii_approved_users_only
  on public.widget_notes;
create policy panpanskii_approved_users_only
on public.widget_notes
as restrictive
for all
to authenticated
using (public.is_panpanskii_approved_user())
with check (public.is_panpanskii_approved_user());

-- ---------------------------------------------------------------------------
-- Storage bucket for the exported note PNGs.
-- Public bucket so the widget can render the drawing without signed URLs;
-- writes are still restricted to the owner folder (user_id prefix).
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('widget-notes', 'widget-notes', true)
on conflict (id) do update
  set public = true;

drop policy if exists widget_notes_storage_insert_own_folder
  on storage.objects;
create policy widget_notes_storage_insert_own_folder
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'widget-notes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists widget_notes_storage_delete_own_folder
  on storage.objects;
create policy widget_notes_storage_delete_own_folder
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'widget-notes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------------
-- Verification (run after the migration: every row should read true)
-- ---------------------------------------------------------------------------
select
  to_regclass('public.widget_notes') is not null as table_exists,
  coalesce((
    select relrowsecurity
    from pg_class
    where oid = 'public.widget_notes'::regclass
  ), false) as rls_enabled,
  (
    select count(*) = 4
    from pg_policies
    where schemaname = 'public'
      and tablename = 'widget_notes'
      and policyname in (
        'widget_notes_select_all',
        'widget_notes_insert_own',
        'widget_notes_delete_own',
        'panpanskii_deny_anon'
      )
  ) as policies_present,
  coalesce((
    select (public = true)
    from storage.buckets
    where id = 'widget-notes'
  ), false) as bucket_ready;

commit;
