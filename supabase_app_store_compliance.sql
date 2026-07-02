-- ============================================================
-- Brew App — App Store compliance backend (run AFTER the other .sql files)
-- Supabase Dashboard → SQL Editor → New Query
--
-- Covers:
--  1. Account deletion (Apple Guideline 5.1.1(v) — mandatory if the app
--     supports account creation)
--  2. Block & report (Apple Guideline 1.2 — mandatory for apps with
--     user-generated content / features that connect strangers, which
--     Coffee Chat does)
-- ============================================================

-- ---- 1. Account deletion ----
-- Deleting the auth.users row cascades through every table that references
-- profiles(id) on delete cascade (drink_logs, friendships, chat_requests,
-- likes, wishlist, blocked_users, reports as reporter) -- one call removes
-- all of a user's data. SECURITY DEFINER lets this reach auth.users (which
-- a plain anon-key client can't touch directly); it is scoped tightly to
-- the calling user's own id, never anyone else's.
create or replace function delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function delete_own_account() to authenticated;

-- ---- 2. Blocking ----
create table if not exists blocked_users (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references profiles(id) on delete cascade,
  blocked_id  uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table blocked_users enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users see their own blocks') then
    create policy "Users see their own blocks"
      on blocked_users for select using (auth.uid() = blocker_id);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Users can block') then
    create policy "Users can block"
      on blocked_users for insert with check (auth.uid() = blocker_id);
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Users can unblock') then
    create policy "Users can unblock"
      on blocked_users for delete using (auth.uid() = blocker_id);
  end if;
end $$;

-- ---- 3. Reporting ----
-- Reports have no SELECT policy for regular users on purpose -- only the
-- developer reviews them (via the Supabase dashboard, which bypasses RLS
-- using the service role). This satisfies Apple's "mechanism to report
-- objectionable content" requirement.
create table if not exists reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null references profiles(id) on delete cascade,
  reported_user_id uuid references profiles(id) on delete set null,
  reported_log_id  uuid references drink_logs(id) on delete set null,
  reason           text not null check (char_length(reason) between 1 and 500),
  created_at       timestamptz not null default now()
);

alter table reports enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Users can submit reports') then
    create policy "Users can submit reports"
      on reports for insert with check (auth.uid() = reporter_id);
  end if;
end $$;

create index if not exists blocked_users_blocker_idx on blocked_users(blocker_id);
