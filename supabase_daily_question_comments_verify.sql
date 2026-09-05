-- READ-ONLY verification for Daily Question comments.
-- Run this manually in Supabase SQL Editor. It changes nothing.

-- 1. The table must exist.
select
  to_regclass('public.daily_question_comments') as comments_table,
  to_regclass('public.daily_question_comments') is not null as table_exists;

-- 2. Review the exact deployed columns and defaults. They must match the
-- DailyQuestionComment model and insert/select keys in daily_question_store.dart.
select
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'daily_question_comments'
order by ordinal_position;

-- 3. Required structural columns.
with required_columns(column_name) as (
  values
    ('id'),
    ('day_key'),
    ('user_id'),
    ('username'),
    ('mascot'),
    ('created_at')
)
select
  required.column_name,
  columns.column_name is not null as exists
from required_columns required
left join information_schema.columns columns
  on columns.table_schema = 'public'
 and columns.table_name = 'daily_question_comments'
 and columns.column_name = required.column_name
order by required.column_name;

-- 4. Identify the deployed comment text field. The application and SQL must
-- use the same one; the field must be NOT NULL and constrained to 1..600
-- trimmed characters.
select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'daily_question_comments'
  and column_name in ('comment_text', 'content', 'message', 'body', 'text')
order by ordinal_position;

-- 5. Primary key, foreign key, day-key, mascot, and text-length constraints.
select
  constraints.conname as constraint_name,
  constraints.contype as constraint_type,
  pg_get_constraintdef(constraints.oid) as definition
from pg_constraint constraints
join pg_class tables
  on tables.oid = constraints.conrelid
join pg_namespace namespaces
  on namespaces.oid = tables.relnamespace
where namespaces.nspname = 'public'
  and tables.relname = 'daily_question_comments'
order by constraints.contype, constraints.conname;

-- 6. Indexes should support day_key ordering and user ownership lookups.
select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'daily_question_comments'
order by indexname;

-- 7. RLS must be enabled.
select
  classes.relrowsecurity as rls_enabled,
  classes.relforcerowsecurity as rls_forced
from pg_class classes
join pg_namespace namespaces
  on namespaces.oid = classes.relnamespace
where namespaces.nspname = 'public'
  and classes.relname = 'daily_question_comments';

-- 8. Policies must permit approved/authenticated reads, own-row inserts, and
-- own-row deletes without allowing a user to impersonate another user_id.
select
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'daily_question_comments'
order by cmd, policyname;

-- 9. Realtime publication membership must return one row.
select
  pubname,
  schemaname,
  tablename
from pg_publication_tables
where schemaname = 'public'
  and tablename = 'daily_question_comments'
order by pubname;

-- 10. Review API privileges. RLS remains the row-level authority.
select
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'daily_question_comments'
  and grantee in ('anon', 'authenticated')
order by grantee, privilege_type;
