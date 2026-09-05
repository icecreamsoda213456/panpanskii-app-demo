create table if not exists public.daily_duo_answers (
  id uuid primary key default gen_random_uuid(),
  day_key text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  option_index smallint not null check (option_index between 0 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (day_key, user_id)
);

alter table public.daily_duo_answers enable row level security;

drop policy if exists "Authenticated users can read daily duo answers"
  on public.daily_duo_answers;
drop policy if exists "Users can create their own daily duo answer"
  on public.daily_duo_answers;
drop policy if exists "Users can update their own daily duo answer"
  on public.daily_duo_answers;

create policy "Authenticated users can read daily duo answers"
  on public.daily_duo_answers
  for select
  to authenticated
  using (true);

create policy "Users can create their own daily duo answer"
  on public.daily_duo_answers
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own daily duo answer"
  on public.daily_duo_answers
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists daily_duo_answers_day_key_idx
  on public.daily_duo_answers (day_key, updated_at desc);

alter table public.daily_duo_answers replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'daily_duo_answers'
  ) then
    alter publication supabase_realtime
      add table public.daily_duo_answers;
  end if;
end $$;
