-- Cozy Garden Phase 2
-- Non-destructive migration. Run once in Supabase Dashboard -> SQL Editor.

begin;

-- Keep the existing Phase 1 garden row and add progression metadata.
alter table public.cozy_garden_state
  add column if not exists current_streak integer not null default 0,
  add column if not exists longest_streak integer not null default 0,
  add column if not exists total_harvests integer not null default 0,
  add column if not exists cycle_started_at timestamptz,
  add column if not exists last_completed_day date,
  add column if not exists last_harvested_at timestamptz;

insert into public.cozy_garden_state (id)
values ('main')
on conflict (id) do nothing;

update public.cozy_garden_state
set current_streak = coalesce(current_streak, 0),
    longest_streak = coalesce(longest_streak, 0),
    total_harvests = coalesce(total_harvests, 0),
    cycle_started_at = coalesce(cycle_started_at, updated_at, now())
where id = 'main';

alter table public.cozy_garden_state
  alter column current_streak set default 0,
  alter column current_streak set not null,
  alter column longest_streak set default 0,
  alter column longest_streak set not null,
  alter column total_harvests set default 0,
  alter column total_harvests set not null;

-- Phase 1 allowed sunflower, rose, and tree. Phase 2 adds unlockable plants.
-- Only the old plant-type CHECK is replaced; no rows are deleted or reset.
do $$
declare
  old_constraint_name text;
begin
  select con.conname
  into old_constraint_name
  from pg_constraint con
  where con.conrelid = 'public.cozy_garden_state'::regclass
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) like '%plant_type%'
    and pg_get_constraintdef(con.oid) not like '%sakura%'
  limit 1;

  if old_constraint_name is not null then
    execute format(
      'alter table public.cozy_garden_state drop constraint %I',
      old_constraint_name
    );
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.cozy_garden_state'::regclass
      and conname = 'cozy_garden_state_plant_type_phase2_check'
  ) then
    alter table public.cozy_garden_state
      add constraint cozy_garden_state_plant_type_phase2_check
      check (
        plant_type in (
          'sunflower',
          'sakura',
          'tulip',
          'rose',
          'lavender',
          'tree'
        )
      ) not valid;
  end if;
end;
$$;

create table if not exists public.cozy_garden_bonus_events (
  id uuid primary key default gen_random_uuid(),
  day_key text not null,
  event_type text not null,
  growth_bonus integer not null default 0 check (growth_bonus >= 0),
  created_at timestamptz not null default now()
);

create unique index if not exists cozy_garden_bonus_events_day_event_key
  on public.cozy_garden_bonus_events (day_key, event_type);

create index if not exists cozy_garden_bonus_events_created_at_idx
  on public.cozy_garden_bonus_events (created_at desc);

create table if not exists public.cozy_garden_harvests (
  id uuid primary key default gen_random_uuid(),
  plant_type text not null,
  started_at timestamptz,
  harvested_at timestamptz not null default now(),
  harvested_by uuid references auth.users(id) on delete set null,
  final_growth integer not null check (final_growth between 0 and 100),
  streak_at_harvest integer,
  created_at timestamptz not null default now()
);

create index if not exists cozy_garden_harvests_harvested_at_idx
  on public.cozy_garden_harvests (harvested_at desc);

create index if not exists cozy_garden_harvests_plant_type_idx
  on public.cozy_garden_harvests (plant_type);

create table if not exists public.cozy_garden_unlocks (
  unlock_key text primary key,
  unlock_type text not null check (unlock_type in ('plant', 'decoration')),
  unlocked_at timestamptz not null default now(),
  unlock_source text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists cozy_garden_unlocks_type_idx
  on public.cozy_garden_unlocks (unlock_type, unlocked_at);

-- New shared progression data is readable by signed-in app users.
alter table public.cozy_garden_bonus_events enable row level security;
alter table public.cozy_garden_harvests enable row level security;
alter table public.cozy_garden_unlocks enable row level security;

grant select on public.cozy_garden_bonus_events to authenticated;
grant select on public.cozy_garden_harvests to authenticated;
grant select on public.cozy_garden_unlocks to authenticated;

-- Phase 1 already uses water_cozy_garden. Keep the shared tables readable,
-- but remove the old direct action-write route so it cannot bypass the RPC.
drop policy if exists "Users can create their own cozy garden action"
  on public.cozy_garden_actions;
revoke insert, update, delete on public.cozy_garden_state
  from anon, authenticated;
revoke insert, update, delete on public.cozy_garden_actions
  from anon, authenticated;
grant select on public.cozy_garden_state to authenticated;
grant select on public.cozy_garden_actions to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'cozy_garden_bonus_events'
      and policyname = 'Authenticated users can read cozy garden bonus events'
  ) then
    create policy "Authenticated users can read cozy garden bonus events"
      on public.cozy_garden_bonus_events
      for select
      to authenticated
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'cozy_garden_harvests'
      and policyname = 'Authenticated users can read cozy garden harvests'
  ) then
    create policy "Authenticated users can read cozy garden harvests"
      on public.cozy_garden_harvests
      for select
      to authenticated
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'cozy_garden_unlocks'
      and policyname = 'Authenticated users can read cozy garden unlocks'
  ) then
    create policy "Authenticated users can read cozy garden unlocks"
      on public.cozy_garden_unlocks
      for select
      to authenticated
      using (true);
  end if;
end;
$$;

-- Parses the existing client day-key format without using device timestamps.
create or replace function public._cozy_garden_day_from_key(p_day_key text)
returns date
language plpgsql
immutable
set search_path = public
as $$
declare
  parsed_day date;
begin
  if p_day_key is null or p_day_key !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'Invalid garden day key.' using errcode = '22007';
  end if;

  parsed_day := p_day_key::date;
  if to_char(parsed_day, 'YYYY-MM-DD') <> p_day_key then
    raise exception 'Invalid garden day key.' using errcode = '22007';
  end if;
  return parsed_day;
exception
  when datetime_field_overflow then
    raise exception 'Invalid garden day key.' using errcode = '22007';
end;
$$;

-- The current app uses Philippine local time with a 6:00 AM garden reset.
-- This calculation is server-side so a modified client cannot invent days.
create or replace function public._cozy_garden_effective_day()
returns date
language sql
stable
set search_path = public
as $$
  select ((now() at time zone 'Asia/Manila') - interval '6 hours')::date;
$$;

-- All progression milestones live in one server-side function.
create or replace function public._cozy_garden_apply_unlocks(
  p_total_harvests integer,
  p_longest_streak integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.cozy_garden_unlocks (
    unlock_key, unlock_type, unlock_source, metadata
  ) values (
    'plant:sunflower',
    'plant',
    'default',
    '{"plant_id":"sunflower"}'::jsonb
  ) on conflict (unlock_key) do nothing;

  if coalesce(p_total_harvests, 0) >= 1 then
    insert into public.cozy_garden_unlocks (
      unlock_key, unlock_type, unlock_source, metadata
    ) values
      (
        'plant:sakura',
        'plant',
        'first_harvest',
        '{"plant_id":"sakura"}'::jsonb
      ),
      (
        'decoration:wooden_sign',
        'decoration',
        'first_harvest',
        '{"decoration_id":"wooden_sign"}'::jsonb
      )
    on conflict (unlock_key) do nothing;
  end if;

  if coalesce(p_longest_streak, 0) >= 3 then
    insert into public.cozy_garden_unlocks (
      unlock_key, unlock_type, unlock_source, metadata
    ) values (
      'decoration:mushroom',
      'decoration',
      'longest_streak_3',
      '{"decoration_id":"mushroom"}'::jsonb
    ) on conflict (unlock_key) do nothing;
  end if;

  if coalesce(p_longest_streak, 0) >= 7 then
    insert into public.cozy_garden_unlocks (
      unlock_key, unlock_type, unlock_source, metadata
    ) values
      (
        'plant:tulip',
        'plant',
        'longest_streak_7',
        '{"plant_id":"tulip"}'::jsonb
      ),
      (
        'decoration:lantern',
        'decoration',
        'longest_streak_7',
        '{"decoration_id":"lantern"}'::jsonb
      )
    on conflict (unlock_key) do nothing;
  end if;

  if coalesce(p_total_harvests, 0) >= 3 then
    insert into public.cozy_garden_unlocks (
      unlock_key, unlock_type, unlock_source, metadata
    ) values
      (
        'plant:rose',
        'plant',
        'total_harvests_3',
        '{"plant_id":"rose"}'::jsonb
      ),
      (
        'decoration:couple_bench',
        'decoration',
        'total_harvests_3',
        '{"decoration_id":"couple_bench"}'::jsonb
      )
    on conflict (unlock_key) do nothing;
  end if;
end;
$$;

-- Backfill the default and any already-earned Phase 2 unlocks without
-- modifying the existing growth, current plant, or action history.
select public._cozy_garden_apply_unlocks(
  coalesce(
    (
      select total_harvests
      from public.cozy_garden_state
      where id = 'main'
    ),
    0
  ),
  coalesce(
    (
      select longest_streak
      from public.cozy_garden_state
      where id = 'main'
    ),
    0
  )
);

insert into public.cozy_garden_unlocks (
  unlock_key, unlock_type, unlock_source, metadata
)
select
  'plant:rose',
  'plant',
  'legacy_current_plant',
  '{"plant_id":"rose"}'::jsonb
where exists (
  select 1
  from public.cozy_garden_state
  where id = 'main'
    and plant_type = 'rose'
)
on conflict (unlock_key) do nothing;

-- Preserves Phase 1's +8 per successful water while awarding a one-time +2
-- server-side Together Bonus only when the second distinct user completes care.
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
  actor_id uuid := auth.uid();
  garden_day date;
  effective_day date;
  locked_garden public.cozy_garden_state;
  result public.cozy_garden_state;
  action_rows integer := 0;
  action_count integer := 0;
  bonus_event_id uuid;
  did_award_together boolean := false;
  next_streak integer;
  streak_is_expired boolean := false;
begin
  if actor_id is null or actor_id <> p_user_id then
    raise exception 'You can only water the garden for your own account.';
  end if;

  if coalesce(trim(p_username), '') = '' then
    raise exception 'A garden username is required.';
  end if;

  if p_mascot not in ('panda', 'koala') then
    raise exception 'Invalid garden mascot.';
  end if;

  garden_day := public._cozy_garden_day_from_key(p_day_key);
  effective_day := public._cozy_garden_effective_day();
  if garden_day <> effective_day then
    raise exception 'Watering is only available for the current garden day.';
  end if;

  insert into public.cozy_garden_state (id)
  values ('main')
  on conflict (id) do nothing;

  select *
  into locked_garden
  from public.cozy_garden_state
  where id = 'main'
  for update;

  streak_is_expired := locked_garden.last_completed_day is null
    or locked_garden.last_completed_day < effective_day - 1;

  insert into public.cozy_garden_actions (
    day_key, user_id, username, mascot
  ) values (
    p_day_key, actor_id, trim(p_username), p_mascot
  ) on conflict (day_key, user_id) do nothing;

  get diagnostics action_rows = row_count;

  if action_rows > 0 then
    select count(distinct user_id)
    into action_count
    from public.cozy_garden_actions
    where day_key = p_day_key;

    if action_count = 2 then
      bonus_event_id := null;
      insert into public.cozy_garden_bonus_events (
        day_key, event_type, growth_bonus
      ) values (
        p_day_key, 'both_watered', 2
      ) on conflict (day_key, event_type) do nothing
      returning id into bonus_event_id;
      did_award_together := found;

      if did_award_together then
        if locked_garden.last_completed_day = garden_day - 1 then
          next_streak := locked_garden.current_streak + 1;
        else
          next_streak := 1;
        end if;

        update public.cozy_garden_state
        set growth = least(100, growth + 8 + 2),
            current_streak = next_streak,
            longest_streak = greatest(longest_streak, next_streak),
            last_completed_day = garden_day,
            last_watered_by = actor_id,
            watered_at = now(),
            updated_at = now()
        where id = 'main';
      else
        update public.cozy_garden_state
        set growth = least(100, growth + 8),
            current_streak = case
              when streak_is_expired then 0
              else current_streak
            end,
            last_watered_by = actor_id,
            watered_at = now(),
            updated_at = now()
        where id = 'main';
      end if;
    else
      update public.cozy_garden_state
      set growth = least(100, growth + 8),
          current_streak = case
            when streak_is_expired then 0
            else current_streak
          end,
          last_watered_by = actor_id,
          watered_at = now(),
          updated_at = now()
      where id = 'main';
    end if;
  end if;

  select *
  into result
  from public.cozy_garden_state
  where id = 'main';

  perform public._cozy_garden_apply_unlocks(
    result.total_harvests,
    result.longest_streak
  );

  return result;
end;
$$;

-- Harvest happens only after a visible 100% bloom and is protected by the
-- locked shared garden row, so two simultaneous taps cannot create two harvests.
create or replace function public.harvest_cozy_garden(p_next_plant text)
returns public.cozy_garden_state
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id uuid := auth.uid();
  next_plant text := lower(trim(coalesce(p_next_plant, '')));
  locked_garden public.cozy_garden_state;
  result public.cozy_garden_state;
  is_next_plant_eligible boolean := false;
begin
  if actor_id is null then
    raise exception 'Please log in again before harvesting.';
  end if;

  if next_plant not in (
    'sunflower', 'sakura', 'tulip', 'rose', 'lavender', 'tree'
  ) then
    raise exception 'Invalid next plant.';
  end if;

  insert into public.cozy_garden_state (id)
  values ('main')
  on conflict (id) do nothing;

  select *
  into locked_garden
  from public.cozy_garden_state
  where id = 'main'
  for update;

  if locked_garden.growth < 100 then
    raise exception 'The garden is not ready to harvest yet.';
  end if;

  is_next_plant_eligible := next_plant = 'sunflower'
    or exists (
      select 1
      from public.cozy_garden_unlocks
      where unlock_key = 'plant:' || next_plant
        and unlock_type = 'plant'
    )
    or (
      next_plant = 'sakura'
      and coalesce(locked_garden.total_harvests, 0) + 1 >= 1
    )
    or (
      next_plant = 'rose'
      and coalesce(locked_garden.total_harvests, 0) + 1 >= 3
    )
    or (
      next_plant = 'tulip'
      and coalesce(locked_garden.longest_streak, 0) >= 7
    );

  if not is_next_plant_eligible then
    raise exception 'That plant is still locked.';
  end if;

  insert into public.cozy_garden_harvests (
    plant_type,
    started_at,
    harvested_by,
    final_growth,
    streak_at_harvest
  ) values (
    locked_garden.plant_type,
    locked_garden.cycle_started_at,
    actor_id,
    locked_garden.growth,
    locked_garden.current_streak
  );

  update public.cozy_garden_state
  set plant_type = next_plant,
      growth = 0,
      total_harvests = total_harvests + 1,
      cycle_started_at = now(),
      last_harvested_at = now(),
      updated_at = now()
  where id = 'main';

  select *
  into result
  from public.cozy_garden_state
  where id = 'main';

  perform public._cozy_garden_apply_unlocks(
    result.total_harvests,
    result.longest_streak
  );

  return result;
end;
$$;

-- This RPC inspects persisted Daily Duo answers itself. Flutter never reports
-- a match; the database awards each event once through the unique event index.
create or replace function public.claim_daily_duo_garden_bonus(p_day_key text)
returns table (
  is_complete boolean,
  is_match boolean,
  awarded_growth integer,
  total_day_bonus integer,
  garden_growth integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id uuid := auth.uid();
  requested_day date;
  answer_count integer := 0;
  lowest_answer smallint;
  highest_answer smallint;
  complete boolean := false;
  matched boolean := false;
  newly_awarded integer := 0;
  event_bonus integer;
  locked_garden public.cozy_garden_state;
  sum_for_day integer := 0;
begin
  if actor_id is null then
    raise exception 'Please log in again before claiming a garden bonus.';
  end if;

  requested_day := public._cozy_garden_day_from_key(p_day_key);
  if requested_day <> public._cozy_garden_effective_day() then
    raise exception 'Daily Duo garden bonuses are only available today.';
  end if;

  if not exists (
    select 1
    from public.daily_duo_answers
    where day_key = p_day_key
      and user_id = actor_id
  ) then
    raise exception 'Answer today''s Daily Duo before claiming its garden bonus.';
  end if;

  insert into public.cozy_garden_state (id)
  values ('main')
  on conflict (id) do nothing;

  select *
  into locked_garden
  from public.cozy_garden_state
  where id = 'main'
  for update;

  select
    count(distinct user_id),
    min(option_index),
    max(option_index)
  into answer_count, lowest_answer, highest_answer
  from public.daily_duo_answers
  where day_key = p_day_key;

  complete := answer_count >= 2;
  matched := answer_count = 2 and lowest_answer = highest_answer;

  if complete then
    event_bonus := null;
    insert into public.cozy_garden_bonus_events (
      day_key, event_type, growth_bonus
    ) values (
      p_day_key, 'daily_duo_complete', 2
    ) on conflict (day_key, event_type) do nothing
    returning growth_bonus into event_bonus;
    if found then
      newly_awarded := newly_awarded + event_bonus;
    end if;

    if matched then
      event_bonus := null;
      insert into public.cozy_garden_bonus_events (
        day_key, event_type, growth_bonus
      ) values (
        p_day_key, 'daily_duo_match', 1
      ) on conflict (day_key, event_type) do nothing
      returning growth_bonus into event_bonus;
      if found then
        newly_awarded := newly_awarded + event_bonus;
      end if;
    end if;

    if newly_awarded > 0 then
      update public.cozy_garden_state
      set growth = least(100, growth + newly_awarded),
          updated_at = now()
      where id = 'main';
    end if;
  end if;

  select coalesce(sum(growth_bonus), 0)
  into sum_for_day
  from public.cozy_garden_bonus_events
  where day_key = p_day_key
    and event_type in ('daily_duo_complete', 'daily_duo_match');

  select growth
  into garden_growth
  from public.cozy_garden_state
  where id = 'main';

  is_complete := complete;
  is_match := matched;
  awarded_growth := newly_awarded;
  total_day_bonus := sum_for_day;
  return next;
end;
$$;

-- Keep direct mutations private. Only authenticated callers receive the three
-- public RPCs, and each RPC validates auth.uid() server-side.
revoke all on function public._cozy_garden_day_from_key(text)
  from public, anon, authenticated;
revoke all on function public._cozy_garden_effective_day()
  from public, anon, authenticated;
revoke all on function public._cozy_garden_apply_unlocks(integer, integer)
  from public, anon, authenticated;
revoke all on function public.water_cozy_garden(text, uuid, text, text)
  from public, anon;
revoke all on function public.harvest_cozy_garden(text)
  from public, anon;
revoke all on function public.claim_daily_duo_garden_bonus(text)
  from public, anon;

grant execute on function public.water_cozy_garden(text, uuid, text, text)
  to authenticated;
grant execute on function public.harvest_cozy_garden(text)
  to authenticated;
grant execute on function public.claim_daily_duo_garden_bonus(text)
  to authenticated;

-- Supabase Realtime supplies the shared progression state to both devices.
alter table public.cozy_garden_bonus_events replica identity full;
alter table public.cozy_garden_unlocks replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cozy_garden_bonus_events'
  ) then
    alter publication supabase_realtime
      add table public.cozy_garden_bonus_events;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cozy_garden_unlocks'
  ) then
    alter publication supabase_realtime
      add table public.cozy_garden_unlocks;
  end if;
end;
$$;

commit;
