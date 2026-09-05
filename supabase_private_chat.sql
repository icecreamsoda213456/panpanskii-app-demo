create table if not exists public.private_chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id text not null default 'main',
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  message text not null check (char_length(trim(message)) > 0),
  created_at timestamptz not null default now()
);

alter table public.private_chat_messages enable row level security;

drop policy if exists "Authenticated users can read private chat"
  on public.private_chat_messages;
drop policy if exists "Authenticated users can send private chat"
  on public.private_chat_messages;

create policy "Authenticated users can read private chat"
  on public.private_chat_messages
  for select
  to authenticated
  using (room_id = 'main');

create policy "Authenticated users can send private chat"
  on public.private_chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and room_id = 'main'
  );

create index if not exists private_chat_messages_room_created_at_idx
  on public.private_chat_messages (room_id, created_at);

create table if not exists public.private_chat_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.private_chat_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  reaction text not null check (reaction in ('love', 'like', 'laugh', 'wow', 'sad')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (message_id, user_id)
);

alter table public.private_chat_reactions enable row level security;

drop policy if exists "Authenticated users can read private chat reactions"
  on public.private_chat_reactions;
drop policy if exists "Users can add private chat reactions"
  on public.private_chat_reactions;
drop policy if exists "Users can update private chat reactions"
  on public.private_chat_reactions;
drop policy if exists "Users can delete private chat reactions"
  on public.private_chat_reactions;

create policy "Authenticated users can read private chat reactions"
  on public.private_chat_reactions
  for select
  to authenticated
  using (true);

create policy "Users can add private chat reactions"
  on public.private_chat_reactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update private chat reactions"
  on public.private_chat_reactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete private chat reactions"
  on public.private_chat_reactions
  for delete
  to authenticated
  using (auth.uid() = user_id);

create index if not exists private_chat_reactions_message_idx
  on public.private_chat_reactions (message_id);

alter table public.private_chat_reactions replica identity full;

alter table public.private_chat_messages replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'private_chat_messages'
  ) then
    alter publication supabase_realtime
      add table public.private_chat_messages;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'private_chat_reactions'
  ) then
    alter publication supabase_realtime
      add table public.private_chat_reactions;
  end if;
end $$;
