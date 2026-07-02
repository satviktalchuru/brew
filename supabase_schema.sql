-- ============================================================
-- Brew App — Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- PROFILES (one row per auth user)
-- ============================================================
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  display_name  text not null,
  is_public     boolean not null default true,
  appear_in_chats boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Users can read any public profile"
  on profiles for select using (is_public = true or auth.uid() = id);

create policy "Users can insert own profile"
  on profiles for insert with check (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);

-- ============================================================
-- DRINK LOGS
-- ============================================================
create table if not exists drink_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  shop_id       uuid,
  is_home_brew  boolean not null default false,
  drink_name    text not null,
  brew_method   text not null,
  roast         text not null,
  sweetness     int not null check (sweetness between 1 and 5),
  strength      int not null check (strength between 1 and 5),
  would_order   text not null default 'yes',
  notes         text not null default '',
  elo_score     double precision not null default 1200,
  flavor_tags   jsonb,
  logged_at     timestamptz not null default now()
);

alter table drink_logs enable row level security;

create policy "Anyone can read drink logs of public users"
  on drink_logs for select
  using (exists (
    select 1 from profiles p where p.id = user_id and (p.is_public = true or p.id = auth.uid())
  ));

create policy "Users can insert own drink logs"
  on drink_logs for insert with check (auth.uid() = user_id);

create policy "Users can update own drink logs"
  on drink_logs for update using (auth.uid() = user_id);

create policy "Users can delete own drink logs"
  on drink_logs for delete using (auth.uid() = user_id);

create index if not exists drink_logs_user_id_idx on drink_logs(user_id);
create index if not exists drink_logs_logged_at_idx on drink_logs(logged_at desc);

-- ============================================================
-- FRIENDSHIPS
-- ============================================================
create table if not exists friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references profiles(id) on delete cascade,
  addressee_id  uuid not null references profiles(id) on delete cascade,
  status        text not null default 'pending'
                  check (status in ('pending','accepted','declined','blocked')),
  created_at    timestamptz not null default now(),
  unique(requester_id, addressee_id)
);

alter table friendships enable row level security;

create policy "Users can see their own friendships"
  on friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Users can request friendships"
  on friendships for insert with check (auth.uid() = requester_id);

create policy "Users can update friendship status"
  on friendships for update using (auth.uid() = addressee_id or auth.uid() = requester_id);

-- ============================================================
-- CHAT REQUESTS
-- ============================================================
create table if not exists chat_requests (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references profiles(id) on delete cascade,
  addressee_id  uuid not null references profiles(id) on delete cascade,
  shop_id       uuid not null,
  status        text not null default 'pending'
                  check (status in ('pending','accepted','declined')),
  requested_at  timestamptz not null default now()
);

alter table chat_requests enable row level security;

create policy "Users can see their own chat requests"
  on chat_requests for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Users can create chat requests"
  on chat_requests for insert with check (auth.uid() = requester_id);

create policy "Addressee can update chat request status"
  on chat_requests for update using (auth.uid() = addressee_id);

-- ============================================================
-- LIKES
-- ============================================================
create table if not exists likes (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references profiles(id) on delete cascade,
  log_id    uuid not null references drink_logs(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, log_id)
);

alter table likes enable row level security;

create policy "Anyone can read likes"
  on likes for select using (true);

create policy "Users can like"
  on likes for insert with check (auth.uid() = user_id);

create policy "Users can unlike"
  on likes for delete using (auth.uid() = user_id);

create index if not exists likes_log_id_idx on likes(log_id);

-- ============================================================
-- Auto-create profile row on signup
-- ============================================================
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
