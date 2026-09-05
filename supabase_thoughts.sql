create table if not exists public.thought_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.thought_reactions (
  id uuid primary key default gen_random_uuid(),
  thought_id uuid not null references public.thought_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  reaction text not null check (reaction in ('love', 'care', 'agree', 'wow', 'sad')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (thought_id, user_id)
);

create table if not exists public.thought_comments (
  id uuid primary key default gen_random_uuid(),
  thought_id uuid not null references public.thought_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  message text not null check (char_length(trim(message)) > 0),
  created_at timestamptz not null default now()
);

alter table public.thought_posts enable row level security;
alter table public.thought_reactions enable row level security;
alter table public.thought_comments enable row level security;

drop policy if exists "Authenticated users can read thoughts"
  on public.thought_posts;
drop policy if exists "Users can post their own thoughts"
  on public.thought_posts;

create policy "Authenticated users can read thoughts"
  on public.thought_posts
  for select
  to authenticated
  using (true);

create policy "Users can post their own thoughts"
  on public.thought_posts
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Authenticated users can read thought reactions"
  on public.thought_reactions;
drop policy if exists "Users can react to thoughts"
  on public.thought_reactions;
drop policy if exists "Users can update their thought reactions"
  on public.thought_reactions;
drop policy if exists "Users can delete their thought reactions"
  on public.thought_reactions;

create policy "Authenticated users can read thought reactions"
  on public.thought_reactions
  for select
  to authenticated
  using (true);

create policy "Users can react to thoughts"
  on public.thought_reactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their thought reactions"
  on public.thought_reactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their thought reactions"
  on public.thought_reactions
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Authenticated users can read thought comments"
  on public.thought_comments;
drop policy if exists "Users can comment on thoughts"
  on public.thought_comments;

create policy "Authenticated users can read thought comments"
  on public.thought_comments
  for select
  to authenticated
  using (true);

create policy "Users can comment on thoughts"
  on public.thought_comments
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create index if not exists thought_posts_created_at_idx
  on public.thought_posts (created_at desc);
create index if not exists thought_reactions_thought_idx
  on public.thought_reactions (thought_id);
create index if not exists thought_comments_thought_created_at_idx
  on public.thought_comments (thought_id, created_at);
