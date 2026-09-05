create table if not exists public.mood_statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  mood text not null check (mood in ('happy', 'loved', 'calm', 'excited', 'tired', 'sad', 'anxious', 'scared', 'grateful', 'hopeful')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.mood_statuses
  drop constraint if exists mood_statuses_mood_check;

alter table public.mood_statuses
  add constraint mood_statuses_mood_check
  check (mood in ('happy', 'loved', 'calm', 'excited', 'tired', 'sad', 'anxious', 'scared', 'grateful', 'hopeful'));

alter table public.mood_statuses enable row level security;

drop policy if exists "Authenticated users can read mood statuses"
  on public.mood_statuses;
drop policy if exists "Users can create their own mood status"
  on public.mood_statuses;
drop policy if exists "Users can update their own mood status"
  on public.mood_statuses;

create policy "Authenticated users can read mood statuses"
  on public.mood_statuses
  for select
  to authenticated
  using (true);

create policy "Users can create their own mood status"
  on public.mood_statuses
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own mood status"
  on public.mood_statuses
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists mood_statuses_updated_at_idx
  on public.mood_statuses (updated_at desc);

alter table public.mood_statuses replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mood_statuses'
  ) then
    alter publication supabase_realtime
      add table public.mood_statuses;
  end if;
end $$;
