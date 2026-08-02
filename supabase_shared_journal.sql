create table if not exists public.shared_journal_entries (
  id uuid primary key default gen_random_uuid(),
  room_id text not null default 'main',
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  title text not null default 'Tonight',
  body text not null check (char_length(trim(body)) > 0),
  entry_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, user_id, entry_date)
);

alter table public.shared_journal_entries enable row level security;

drop policy if exists "Authenticated users can read shared journal"
  on public.shared_journal_entries;
drop policy if exists "Users can write their own shared journal"
  on public.shared_journal_entries;
drop policy if exists "Users can update their own shared journal"
  on public.shared_journal_entries;

create policy "Authenticated users can read shared journal"
  on public.shared_journal_entries
  for select
  to authenticated
  using (room_id = 'main');

create policy "Users can write their own shared journal"
  on public.shared_journal_entries
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and room_id = 'main'
  );

create policy "Users can update their own shared journal"
  on public.shared_journal_entries
  for update
  to authenticated
  using (
    auth.uid() = user_id
    and room_id = 'main'
  )
  with check (
    auth.uid() = user_id
    and room_id = 'main'
  );

create index if not exists shared_journal_entries_room_date_idx
  on public.shared_journal_entries (room_id, entry_date desc, updated_at desc);

alter table public.shared_journal_entries replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shared_journal_entries'
  ) then
    alter publication supabase_realtime
      add table public.shared_journal_entries;
  end if;
end $$;
