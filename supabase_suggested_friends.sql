-- ============================================================
-- Brew App — Suggested Friends (friends-of-friends)
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- REQUIRES supabase_app_store_compliance.sql to be run FIRST
-- (this references the blocked_users table it creates).
--
-- RLS on `friendships` only lets a user read rows they're personally part
-- of, so "who are my friends' other friends" can't be computed from the
-- client. This SECURITY DEFINER function computes it server-side, scoped
-- to the calling user (auth.uid()) only — it never exposes another user's
-- raw friendship list, just the aggregated suggestion.
-- ============================================================

create or replace function suggested_friends(limit_count int default 10)
returns table (
  id uuid,
  username text,
  display_name text,
  is_public boolean,
  appear_in_chats boolean,
  mutual_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  with my_friends as (
    select case when requester_id = auth.uid() then addressee_id else requester_id end as friend_id
    from friendships
    where status = 'accepted' and (requester_id = auth.uid() or addressee_id = auth.uid())
  ),
  friends_of_friends as (
    select
      case when f.requester_id = mf.friend_id then f.addressee_id else f.requester_id end as candidate_id
    from friendships f
    join my_friends mf on (f.requester_id = mf.friend_id or f.addressee_id = mf.friend_id)
    where f.status = 'accepted'
  ),
  already_connected as (
    select addressee_id as other_id from friendships where requester_id = auth.uid()
    union
    select requester_id as other_id from friendships where addressee_id = auth.uid()
  ),
  blocked_either_way as (
    select blocked_id as other_id from blocked_users where blocker_id = auth.uid()
    union
    select blocker_id as other_id from blocked_users where blocked_id = auth.uid()
  )
  select p.id, p.username, p.display_name, p.is_public, p.appear_in_chats, count(*) as mutual_count
  from friends_of_friends fof
  join profiles p on p.id = fof.candidate_id
  where fof.candidate_id <> auth.uid()
    and fof.candidate_id not in (select other_id from already_connected)
    and fof.candidate_id not in (select other_id from blocked_either_way)
    and p.is_public = true
  group by p.id, p.username, p.display_name, p.is_public, p.appear_in_chats
  order by mutual_count desc, p.username asc
  limit greatest(limit_count, 0);
$$;

grant execute on function suggested_friends(int) to authenticated;
