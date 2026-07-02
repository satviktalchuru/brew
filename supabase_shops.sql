-- ============================================================
-- Brew App — Shops table (real coffee shops discovered via MapKit)
-- Run in: Supabase Dashboard → SQL Editor → New Query
--
-- Shops are shared reference data: whichever user's device first
-- discovers/logs at a real-world coffee shop inserts it here (id is a
-- deterministic UUID derived client-side from name+coordinate, so repeat
-- discoveries of the same real place upsert onto the same row instead of
-- duplicating). Every signed-in user can read the full directory and add
-- new shops; nobody can edit/delete another user's discovery.
-- ============================================================

create table if not exists shops (
  id           uuid primary key,
  name         text not null check (char_length(name) between 1 and 200),
  address      text not null default '' check (char_length(address) <= 300),
  hours        text not null default '' check (char_length(hours) <= 100),
  hero_symbol  text not null default 'cup.and.saucer.fill' check (char_length(hero_symbol) <= 60),
  latitude     double precision not null,
  longitude    double precision not null,
  created_at   timestamptz not null default now()
);

alter table shops enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'Any authenticated user can read shops') then
    create policy "Any authenticated user can read shops"
      on shops for select using (auth.role() = 'authenticated');
  end if;
  if not exists (select 1 from pg_policies where policyname = 'Any authenticated user can add shops') then
    create policy "Any authenticated user can add shops"
      on shops for insert with check (auth.role() = 'authenticated');
  end if;
end $$;

create index if not exists shops_lat_lng_idx on shops(latitude, longitude);
