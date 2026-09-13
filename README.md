# Brew

A native iOS app for ranking the coffee you actually drink — Beli-style
head-to-head comparisons applied to coffee, tea, and home brews instead of
restaurants.

## The Problem

Star ratings don't work for taste. A 4-star latte and a 4-star pour-over
tell you nothing about which one you'd actually order again. Most coffee
logging apps (or generic food apps repurposed for coffee) fall back to
1–5 stars or check-ins, which collapse everything into the same flat scale
and don't capture *preference* — only satisfaction in the moment.

Brew replaces star ratings with **pairwise comparisons**: after logging a
drink, you're occasionally asked "this or that?" against another drink
you've had. Over time this builds a personal Elo-based ranking that's far
more honest than a star average, because it's built from relative
judgments instead of absolute ones.

## What It Does

- **Log drinks** — brew method, roast, sweetness, strength, notes, and
  optional shop, whether it's a café order or a home brew.
- **Head-to-head ranking** — after each log, compare it against past
  drinks; an Elo rating system (`EloCalculator`) updates both drinks'
  scores based on the outcome.
- **Taste profile** — a running picture of your preferences (sweetness,
  strength, roast leaning) derived from your logs and comparisons
  (`TasteProfileEngine`), used to power shop/drink recommendations.
- **Explore** — real coffee shops near you via MapKit (`PlacesService`),
  with search, filtering by brew method, and trending drinks.
- **Social** — friends, friend suggestions based on mutual connections,
  a feed of friends' logs, likes, and in-app "coffee chat" requests to
  meet up at a shop.
- **Wishlist** — save drinks or shops you want to try.
- **Flavor wheel** — visual breakdown of the flavor tags you log most.
- **Year in Brew** — an annual recap (swipeable cards) of your stats:
  drinks logged, shops visited, top drink, taste identity.
- **Safety** — block/report other users, and full account deletion
  in-app (required for App Store approval when an app supports account
  creation).

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI, iOS 17+ | Native, no cross-platform overhead for a single-platform app |
| State | `@Observable` (Observation framework) | Simpler than Combine for this app's scale |
| Backend | [Supabase](https://supabase.com) (Postgres + Auth), called directly via `URLSession` | Free tier, real Postgres, row-level security — no custom backend to run |
| Auth | Email + password only, plus Sign in with Apple support in the codebase | No Google/third-party OAuth — kept deliberately simple; Apple Sign-In alongside email keeps App Store Guideline 4.8 satisfied if third-party login is ever reintroduced |
| Location / Places | Apple `MapKit` (`MKLocalSearch`) | Free, no API key, no billing account — used instead of Google Places |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) | The `.xcodeproj` is generated, not hand-maintained — run `xcodegen generate` after changing `project.yml` or adding new files |

No third-party SDKs beyond Apple's own frameworks (CoreLocation, MapKit,
UserNotifications, AuthenticationServices) and Supabase's REST API — no
analytics, ads, or crash reporting SDKs.

## Project Structure

```
BrewApp/
├── App/            App entry point, root navigation/tab structure
├── Screens/        One SwiftUI view per screen (Explore, Onboarding, etc.)
├── Services/        Auth, Supabase REST client, location, places search,
│                     notifications, keychain
├── Data/           AppStore (single source of truth, @Observable) + its
│                     Supabase sync extension + offline write queue
├── Logic/          Elo ranking, taste profile, recommendations
├── Models/         Shared data types (Shop, DrinkLog, BrewUser, ...)
├── DesignSystem/   Theme tokens (BrewTheme) and shared components
└── Assets.xcassets App icon, launch screen assets, color sets
```

## Backend Setup (Supabase)

The SQL files in `supabase/` are meant to be run in order, in the
Supabase Dashboard → SQL Editor:

1. `supabase/supabase_schema.sql` — core tables (profiles, drink_logs, friendships,
   chat_requests, likes) and the `handle_new_user()` trigger that creates
   a `profiles` row on signup.
2. `supabase/supabase_shops.sql` — shared shops table (real-world cafes discovered
   via MapKit get upserted here so friends can resolve shop names).
3. `supabase/supabase_wishlist.sql` — wishlist table.
4. `supabase/supabase_suggested_friends.sql` — friend-of-friend suggestion query.
5. `supabase/supabase_app_store_compliance.sql` — `blocked_users`, `reports`, and
   the `delete_own_account()` RPC (Apple Guideline 5.1.1(v) requires
   in-app account deletion for any app that supports account creation).
6. `supabase/supabase_hardening.sql` — additional check constraints (string
   length limits, username format, etc.) layered on after the fact.
7. `supabase/supabase_fix_signup_trigger.sql` — **run this after `supabase/supabase_hardening.sql`**.
   The original `handle_new_user()` trigger derives usernames directly
   from the email's local part (e.g. `"John.Doe"` from
   `John.Doe@gmail.com`), but the hardening migration's
   `profiles_username_fmt` constraint requires lowercase
   alphanumeric/underscore only. Without this fix, sign-up fails for
   most real email addresses with a generic `"Database error saving new
   user"` (HTTP 500) — this file normalizes/sanitizes the derived
   username so it always satisfies the constraint.
8. `supabase/supabase_avatar_storage.sql` — avatar storage bucket,
   `profiles.avatar_url`, and the avatar-aware `suggested_friends()` RPC.

The Supabase project URL and anon key live in
`BrewApp/Services/SupabaseService.swift` (`SupabaseConfig`). The anon key
is safe to ship client-side — row-level security policies on every table
are what actually gate access, not the key.

## Running Locally

```bash
xcodegen generate      # regenerates Brew.xcodeproj from project.yml
open Brew.xcodeproj
```

Requires a full Xcode install (not just Command Line Tools) to build and
run on a simulator or device.

## Demo Mode

The sign-in screen has a "Demo Mode" button that bypasses auth entirely
and runs on locally seeded mock data (`MockData.swift`) — useful for UI
work or screenshots without touching the real backend. Signing in with a
real account clears all seeded mock data (shops, users, comparisons) so
it never leaks into a real session.

## Privacy & App Store

- Privacy policy: hosted as a static page (see `docs/privacy.html`);
  the live URL is set in `SettingsView.swift` (`privacyPolicyURL`).
- `BrewApp/PrivacyInfo.xcprivacy` declares the data types actually
  collected (email, user ID, user-generated content) per Apple's privacy
  manifest requirements.
- No location data is ever transmitted to the backend — `LocationService`
  keeps the device's coordinate in memory only, used purely to compute
  on-device distances and to center MapKit shop searches.
