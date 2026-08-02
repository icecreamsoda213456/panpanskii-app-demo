create table if not exists public.photobooth_sessions (
  id uuid primary key default gen_random_uuid(),
  room_id text not null default 'main',
  created_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'waiting'
    check (status in ('waiting', 'capturing', 'complete', 'cancelled')),
  total_frames smallint not null default 4 check (total_frames between 1 and 6),
  current_frame smallint not null default 0 check (current_frame between 0 and 5),
  capture_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.photobooth_sessions
  alter column total_frames set default 5;

alter table public.photobooth_sessions
  add column if not exists ready_user_ids uuid[] not null default '{}';

alter table public.photobooth_sessions
  drop constraint if exists photobooth_sessions_status_check;

alter table public.photobooth_sessions
  add constraint photobooth_sessions_status_check
  check (status in ('waiting', 'capturing', 'complete', 'cancelled'));

create table if not exists public.photobooth_photos (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.photobooth_sessions(id) on delete cascade,
  frame_index smallint not null check (frame_index between 0 and 5),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  storage_path text not null,
  created_at timestamptz not null default now(),
  unique (session_id, frame_index, user_id)
);

create table if not exists public.photobooth_signals (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.photobooth_sessions(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  signal_type text not null check (signal_type in ('offer', 'answer', 'ice')),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.photobooth_sessions enable row level security;
alter table public.photobooth_photos enable row level security;
alter table public.photobooth_signals enable row level security;

drop policy if exists "Authenticated users can read photobooth sessions"
  on public.photobooth_sessions;
create policy "Authenticated users can read photobooth sessions"
  on public.photobooth_sessions
  for select
  to authenticated
  using (true);

drop policy if exists "Users can create photobooth sessions"
  on public.photobooth_sessions;
create policy "Users can create photobooth sessions"
  on public.photobooth_sessions
  for insert
  to authenticated
  with check (auth.uid() = created_by);

drop policy if exists "Authenticated users can update photobooth sessions"
  on public.photobooth_sessions;
create policy "Authenticated users can update photobooth sessions"
  on public.photobooth_sessions
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Authenticated users can read photobooth photos"
  on public.photobooth_photos;
create policy "Authenticated users can read photobooth photos"
  on public.photobooth_photos
  for select
  to authenticated
  using (true);

drop policy if exists "Users can upload their photobooth photos"
  on public.photobooth_photos;
create policy "Users can upload their photobooth photos"
  on public.photobooth_photos
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Authenticated users can read photobooth signals"
  on public.photobooth_signals;
create policy "Authenticated users can read photobooth signals"
  on public.photobooth_signals
  for select
  to authenticated
  using (true);

drop policy if exists "Users can send photobooth signals"
  on public.photobooth_signals;
create policy "Users can send photobooth signals"
  on public.photobooth_signals
  for insert
  to authenticated
  with check (auth.uid() = sender_id);

create index if not exists photobooth_sessions_room_updated_idx
  on public.photobooth_sessions (room_id, updated_at desc);
create index if not exists photobooth_photos_session_frame_idx
  on public.photobooth_photos (session_id, frame_index, created_at);
create index if not exists photobooth_signals_session_created_idx
  on public.photobooth_signals (session_id, created_at);

create or replace function public.set_photobooth_ready(
  p_session_id uuid,
  p_ready boolean
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  current_ids uuid[];
  result public.photobooth_sessions;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to join the photo booth.';
  end if;

  select coalesce(ready_user_ids, '{}')
  into current_ids
  from public.photobooth_sessions
  where id = p_session_id
  for update;

  if current_ids is null then
    raise exception 'Photo booth session not found.';
  end if;

  if p_ready then
    if not (auth.uid() = any(current_ids)) then
      if cardinality(current_ids) >= 2 then
        raise exception 'This photo booth already has two participants.';
      end if;
      current_ids := array_append(current_ids, auth.uid());
    end if;
  else
    current_ids := array_remove(current_ids, auth.uid());
  end if;

  update public.photobooth_sessions
  set ready_user_ids = current_ids,
      status = case
        when cardinality(current_ids) >= 2 then 'capturing'
        else 'waiting'
      end,
      capture_at = case
        when cardinality(current_ids) >= 2 then now() + interval '5 seconds'
        else now() + interval '1 day'
      end,
      updated_at = now()
  where id = p_session_id
  returning * into result;

  return result;
end;
$$;

grant execute on function public.set_photobooth_ready(uuid, boolean)
  to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'photobooth-photos',
  'photobooth-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload photobooth files"
  on storage.objects;
create policy "Users can upload photobooth files"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'photobooth-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Authenticated users can read photobooth files"
  on storage.objects;
create policy "Authenticated users can read photobooth files"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'photobooth-photos');

alter table public.photobooth_sessions replica identity full;
alter table public.photobooth_photos replica identity full;
alter table public.photobooth_signals replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'photobooth_sessions'
  ) then
    alter publication supabase_realtime
      add table public.photobooth_sessions;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'photobooth_photos'
  ) then
    alter publication supabase_realtime
      add table public.photobooth_photos;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'photobooth_signals'
  ) then
    alter publication supabase_realtime
      add table public.photobooth_signals;
  end if;
end $$;

-- Add frame_style column to photobooth_sessions for gallery filtering
alter table public.photobooth_sessions
add column if not exists frame_style text not null default 'vintage'
check (frame_style in ('vintage', 'sakura', 'midnight'));

-- Create index for filtering by frame style
create index if not exists photobooth_sessions_frame_style_idx
on public.photobooth_sessions (frame_style, created_at desc);

-- Create index for filtering by date
create index if not exists photobooth_sessions_created_at_idx
on public.photobooth_sessions (created_at desc);

-- A guest can request a clean renegotiation after an Android resume without
-- ever becoming an offerer. The session creator remains the only offerer.
alter table public.photobooth_signals
  drop constraint if exists photobooth_signals_signal_type_check;

alter table public.photobooth_signals
  add constraint photobooth_signals_signal_type_check
  check (signal_type in ('offer', 'answer', 'ice', 'reconnect'));

-- Atomic session creation. The advisory lock makes two simultaneous Start taps
-- return one shared waiting/capturing session instead of creating two rows.
create or replace function public.create_or_get_photobooth_session(
  p_room_id text,
  p_frame_style text,
  p_total_frames integer default 5
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to start the photo booth.';
  end if;

  if p_room_id is null or btrim(p_room_id) = '' then
    raise exception 'A photo booth room is required.';
  end if;

  if p_frame_style not in ('vintage', 'sakura', 'midnight') then
    raise exception 'The selected photo frame is not supported.';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_room_id));

  select *
  into result
  from public.photobooth_sessions
  where room_id = p_room_id
    and status in ('waiting', 'capturing')
  order by updated_at desc
  limit 1
  for update;

  if result.id is not null then
    return result;
  end if;

  insert into public.photobooth_sessions (
    room_id,
    created_by,
    status,
    total_frames,
    current_frame,
    frame_style,
    capture_at,
    ready_user_ids
  )
  values (
    p_room_id,
    auth.uid(),
    'waiting',
    greatest(1, least(coalesce(p_total_frames, 5), 5)),
    0,
    p_frame_style,
    now() + interval '1 day',
    '{}'
  )
  returning * into result;

  return result;
end;
$$;

grant execute on function public.create_or_get_photobooth_session(text, text, integer)
  to authenticated;

-- A duplicate Ready tap returns the existing row unchanged, especially
-- preserving capture_at so it cannot restart an active countdown.
create or replace function public.set_photobooth_ready(
  p_session_id uuid,
  p_ready boolean
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  current_ids uuid[];
  result public.photobooth_sessions;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to join the photo booth.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;

  if result.id is null then
    raise exception 'Photo booth session not found.';
  end if;

  if result.status in ('complete', 'cancelled') then
    raise exception 'This photo booth session is no longer active.';
  end if;

  current_ids := coalesce(result.ready_user_ids, '{}');

  if p_ready and auth.uid() = any(current_ids) then
    return result;
  end if;

  if not p_ready and not (auth.uid() = any(current_ids)) then
    return result;
  end if;

  if p_ready then
    if cardinality(current_ids) >= 2 then
      raise exception 'This photo booth already has two participants.';
    end if;
    current_ids := array_append(current_ids, auth.uid());
  else
    current_ids := array_remove(current_ids, auth.uid());
  end if;

  update public.photobooth_sessions
  set ready_user_ids = current_ids,
      status = case
        when cardinality(current_ids) >= 2 then 'capturing'
        else 'waiting'
      end,
      capture_at = case
        when cardinality(current_ids) >= 2 then now() + interval '5 seconds'
        else now() + interval '1 day'
      end,
      updated_at = now()
  where id = p_session_id
  returning * into result;

  return result;
end;
$$;

grant execute on function public.set_photobooth_ready(uuid, boolean)
  to authenticated;

-- Only the session creator advances, and only after two distinct uploads exist
-- for exactly the frame that is being advanced.
create or replace function public.advance_photobooth_session(
  p_session_id uuid,
  p_expected_frame integer
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions;
  uploaded_users integer;
  next_frame integer;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to advance the photo booth.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;

  if result.id is null then
    raise exception 'Photo booth session not found.';
  end if;

  if result.created_by <> auth.uid() then
    raise exception 'Only the photo booth host can advance a frame.';
  end if;

  if result.current_frame > p_expected_frame then
    return result;
  end if;

  if result.status <> 'capturing' or result.current_frame <> p_expected_frame then
    raise exception 'The requested photo booth frame is no longer active.';
  end if;

  select count(distinct user_id)
  into uploaded_users
  from public.photobooth_photos
  where session_id = p_session_id
    and frame_index = p_expected_frame
    and user_id = any(coalesce(result.ready_user_ids, '{}'));

  if uploaded_users < 2 then
    raise exception 'Waiting for both camera frames before advancing.';
  end if;

  next_frame := result.current_frame + 1;
  update public.photobooth_sessions
  set current_frame = next_frame,
      status = case
        when next_frame >= result.total_frames then 'complete'
        else 'capturing'
      end,
      capture_at = case
        when next_frame >= result.total_frames then capture_at
        else now() + interval '4 seconds'
      end,
      updated_at = now()
  where id = p_session_id
  returning * into result;

  return result;
end;
$$;

grant execute on function public.advance_photobooth_session(uuid, integer)
  to authenticated;

create or replace function public.cancel_photobooth_session(
  p_session_id uuid
)
returns public.photobooth_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.photobooth_sessions;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to cancel the photo booth.';
  end if;

  select *
  into result
  from public.photobooth_sessions
  where id = p_session_id
  for update;

  if result.id is null then
    raise exception 'Photo booth session not found.';
  end if;

  if result.created_by <> auth.uid() and
      not (auth.uid() = any(coalesce(result.ready_user_ids, '{}'))) then
    raise exception 'You are not part of this photo booth session.';
  end if;

  if result.status in ('complete', 'cancelled') then
    return result;
  end if;

  update public.photobooth_sessions
  set status = 'cancelled',
      ready_user_ids = '{}',
      capture_at = now() + interval '1 day',
      updated_at = now()
  where id = p_session_id
  returning * into result;

  return result;
end;
$$;

grant execute on function public.cancel_photobooth_session(uuid)
  to authenticated;

-- Session rows are controlled only by the RPCs above. This prevents an app
-- client from bypassing the atomic create, Ready, or frame-advance rules.
drop policy if exists "Users can create photobooth sessions"
  on public.photobooth_sessions;
drop policy if exists "Authenticated users can update photobooth sessions"
  on public.photobooth_sessions;

drop policy if exists "Users can update their photobooth photos"
  on public.photobooth_photos;
create policy "Users can update their photobooth photos"
  on public.photobooth_photos
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their photobooth files"
  on storage.objects;
create policy "Users can update their photobooth files"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'photobooth-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'photobooth-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
