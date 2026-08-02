create table if not exists public.cozy_garden_state (
  id text primary key default 'main',
  plant_type text not null default 'sunflower'
    check (plant_type in ('sunflower', 'rose', 'tree')),
  growth smallint not null default 0 check (growth between 0 and 100),
  last_watered_by uuid references auth.users(id) on delete set null,
  watered_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.cozy_garden_actions (
  id uuid primary key default gen_random_uuid(),
  day_key text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  action text not null default 'water' check (action = 'water'),
  created_at timestamptz not null default now(),
  unique (day_key, user_id)
);

alter table public.cozy_garden_state enable row level security;
alter table public.cozy_garden_actions enable row level security;

drop policy if exists "Authenticated users can read cozy garden state"
  on public.cozy_garden_state;
create policy "Authenticated users can read cozy garden state"
  on public.cozy_garden_state
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can read cozy garden actions"
  on public.cozy_garden_actions;
create policy "Authenticated users can read cozy garden actions"
  on public.cozy_garden_actions
  for select
  to authenticated
  using (true);

drop policy if exists "Users can create their own cozy garden action"
  on public.cozy_garden_actions;
create policy "Users can create their own cozy garden action"
  on public.cozy_garden_actions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create index if not exists cozy_garden_actions_day_key_idx
  on public.cozy_garden_actions (day_key, created_at);

alter table public.cozy_garden_state replica identity full;
alter table public.cozy_garden_actions replica identity full;

create or replace function public.water_cozy_garden(
  p_day_key text,
  p_user_id uuid,
  p_username text,
  p_mascot text
)
returns public.cozy_garden_state
language plpgsql
security definer
set search_path = public
as $$
declare
  did_add_action boolean;
  result public.cozy_garden_state;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'You can only water the garden for your own account.';
  end if;

  if p_mascot not in ('panda', 'koala') then
    raise exception 'Invalid garden mascot.';
  end if;

  insert into public.cozy_garden_state (id)
  values ('main')
  on conflict (id) do nothing;

  insert into public.cozy_garden_actions (
    day_key, user_id, username, mascot
  ) values (
    p_day_key, p_user_id, p_username, p_mascot
  )
  on conflict (day_key, user_id) do nothing;

  did_add_action := found;

  if did_add_action then
    update public.cozy_garden_state
    set growth = least(100, growth + 8),
        last_watered_by = p_user_id,
        watered_at = now(),
        updated_at = now()
    where id = 'main';
  end if;

  select * into result
  from public.cozy_garden_state
  where id = 'main';
  return result;
end;
$$;

grant execute on function public.water_cozy_garden(text, uuid, text, text)
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cozy_garden_state'
  ) then
    alter publication supabase_realtime
      add table public.cozy_garden_state;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cozy_garden_actions'
  ) then
    alter publication supabase_realtime
      add table public.cozy_garden_actions;
  end if;
end $$;
