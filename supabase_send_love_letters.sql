create table if not exists public.send_love_letters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  message text not null check (char_length(trim(message)) > 0),
  attachment_path text,
  created_at timestamptz not null default now()
);

alter table public.send_love_letters
  add column if not exists attachment_path text;

alter table public.send_love_letters enable row level security;

drop policy if exists "Users can insert their own send love letters"
  on public.send_love_letters;
drop policy if exists "Users can read their own send love letters"
  on public.send_love_letters;
drop policy if exists "Authenticated users can read send love letters"
  on public.send_love_letters;

create policy "Users can insert their own send love letters"
  on public.send_love_letters
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Authenticated users can read send love letters"
  on public.send_love_letters
  for select
  to authenticated
  using (true);

create index if not exists send_love_letters_user_created_at_idx
  on public.send_love_letters (user_id, created_at desc);
create index if not exists send_love_letters_created_at_idx
  on public.send_love_letters (created_at desc);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'send-love-attachments',
  'send-love-attachments',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload their own send love attachments"
  on storage.objects;
drop policy if exists "Users can read their own send love attachments"
  on storage.objects;
drop policy if exists "Authenticated users can read send love attachments"
  on storage.objects;

create policy "Users can upload their own send love attachments"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'send-love-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Authenticated users can read send love attachments"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'send-love-attachments'
  );

create table if not exists public.send_love_reactions (
  id uuid primary key default gen_random_uuid(),
  letter_id uuid not null references public.send_love_letters(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  reaction text not null check (reaction in ('love', 'care', 'laugh', 'wow', 'sad')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (letter_id, user_id)
);

create table if not exists public.send_love_comments (
  id uuid primary key default gen_random_uuid(),
  letter_id uuid not null references public.send_love_letters(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  mascot text not null check (mascot in ('panda', 'koala')),
  message text not null check (char_length(trim(message)) > 0),
  created_at timestamptz not null default now()
);

alter table public.send_love_reactions enable row level security;
alter table public.send_love_comments enable row level security;

drop policy if exists "Authenticated users can read send love reactions"
  on public.send_love_reactions;
drop policy if exists "Users can react to send love letters"
  on public.send_love_reactions;
drop policy if exists "Users can update their send love reactions"
  on public.send_love_reactions;
drop policy if exists "Users can delete their send love reactions"
  on public.send_love_reactions;

create policy "Authenticated users can read send love reactions"
  on public.send_love_reactions
  for select
  to authenticated
  using (true);

create policy "Users can react to send love letters"
  on public.send_love_reactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their send love reactions"
  on public.send_love_reactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their send love reactions"
  on public.send_love_reactions
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Authenticated users can read send love comments"
  on public.send_love_comments;
drop policy if exists "Users can comment on send love letters"
  on public.send_love_comments;

create policy "Authenticated users can read send love comments"
  on public.send_love_comments
  for select
  to authenticated
  using (true);

create policy "Users can comment on send love letters"
  on public.send_love_comments
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create index if not exists send_love_reactions_letter_idx
  on public.send_love_reactions (letter_id);
create index if not exists send_love_comments_letter_created_at_idx
  on public.send_love_comments (letter_id, created_at);
