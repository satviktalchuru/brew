# Brew Local SwiftUI Prototype Design

Date: 2026-06-29
Status: Approved for planning

## Goal

Build a real SwiftUI iOS prototype of Brew in `/Users/satviktalchuru/ranking-app`. The prototype should make the product feel tangible before backend and location integrations are added. It uses native SwiftUI, local mock data, and production-shaped boundaries for future Supabase, Google Places, MapKit, auth, and push notification work.

## Scope

The first build is a local product-feel MVP, not a backend-first app.

Included:
- Five-tab app shell: Home, Explore, Log, Friends, Profile.
- Brew design system: warm editorial colors, typography fallbacks, chips, cards, dot indicators, and accent CTAs.
- Mock data for users, shops, drink logs, flavor tags, likes, friends, and coffee chat requests.
- Functional local drink logging.
- Post-log head-to-head comparison sheet when there are at least two drinks.
- Local ELO updates after comparisons.
- Local taste profile computation for the Profile tab.
- Shop detail, drink detail, friend profile, and ranked list flows using local data.

Deferred:
- Supabase schema, auth, storage, realtime, and RLS.
- Google Places search and place photo integration.
- Live MapKit shop discovery.
- APNs or notification delivery.
- In-app camera/photo picker persistence.
- Taste Wrapped and generated share images.
- App Store/TestFlight packaging.

## Architecture

The app will be a SwiftUI project with a small, explicit feature structure:

- `BrewApp`: app entry point and root dependency setup.
- `AppStore`: single observable local store for prototype state.
- `Models`: value types for `User`, `Shop`, `DrinkLog`, `FlavorTag`, `Friendship`, `CoffeeChatRequest`, and `Comparison`.
- `DesignSystem`: colors, typography helpers, buttons, cards, chips, dot ratings, and reusable row styles.
- `Features/Home`: feed, feed cards, empty state, drink detail navigation.
- `Features/Explore`: mock shop discovery list and shop detail.
- `Features/Log`: full-screen log flow and local validation.
- `Features/Ranking`: head-to-head sheet, pair selection, and ELO helpers.
- `Features/Friends`: friend list, coffee chat requests, add friend placeholder, friend profile.
- `Features/Profile`: profile header, taste profile card/detail, ranked lists, recent activity.
- `Data`: mock seed data and pure computation helpers.

The local store is intentionally simple. It should make user interactions feel real while keeping future API wiring straightforward. Backend services can later replace store methods such as `addDrinkLog`, `toggleLike`, `acceptChatRequest`, and `recordComparison`.

## Navigation

The root uses `TabView` with five tabs:

- Home
- Explore
- Log
- Friends
- Profile

The Log tab presents the log flow as a full-screen modal and then returns to the previous selected tab after save or cancel. Home, Explore, Friends, and Profile each use `NavigationStack` for pushed detail screens.

## Screen Design

### Home

Home shows a large "brew" title, grouped feed sections, and friend check-in cards. Each card includes avatar, friend/shop context, drink name, roast/flavor chips, sweetness and strength dots, optional notes, and like/share affordances. Empty state copy invites the user to log a drink or find friends.

### Explore

Explore is a polished mock shop discovery experience rather than a live map. It shows a search field, nearby shop cards, drink counts, friend avatar stacks, and navigation to Shop Detail. This preserves the product intent while avoiding MapKit and location scope in the local prototype.

### Shop Detail

Shop Detail shows a hero-style shop header, address/hours, "What to Order" ranked cards, friends who have logged at the shop, coffee chat candidates, and all drinks logged there. A "Log here" button opens Log with the shop preselected.

### Log

The Log flow is a full-screen SwiftUI modal with local state:

- Shop/Home Brew segmented control.
- Shop picker from mock nearby shops or "Home Brew" label.
- Drink name, roast, brew method, sweetness, and strength inputs.
- Flavor category/descriptor chip picker capped at five selections.
- Notes, would-order-again selection, and save.

Save is enabled only when the drink name and would-order-again fields are valid. Saving creates a local `DrinkLog`, updates rankings, dismisses the modal, shows local confirmation state, and opens Head-to-Head when eligible.

### Head-To-Head

The head-to-head sheet shows two drink cards and asks which one the user preferred. Pair selection prioritizes uncompared drinks with the closest ELO scores. Choosing a winner records a comparison and updates local ELO scores. The sheet may show up to two rounds in one session.

### Friends

Friends shows coffee chat requests, upcoming chats, and accepted friends. Add Friend is a pushed placeholder with mock search results and row states. Coffee chat accept/decline updates local request status.

### Profile

Profile shows the user's avatar, display name, username, stats, taste profile card, segmented rankings for shop drinks and home brews, and recent activity. Taste profile data is computed from local drink logs.

## Data Flow

`AppStore` owns arrays of model data and exposes methods for state changes. Views read the store through SwiftUI environment injection. Derived values such as feed groups, ranked drinks, shop aggregates, and taste profile summaries are computed through pure helper functions so they can be unit tested without SwiftUI.

Important store actions:

- `addDrinkLog(_:)`
- `toggleLike(logID:)`
- `recordComparison(winnerID:loserID:)`
- `candidateComparisonPairs()`
- `acceptChatRequest(_:)`
- `declineChatRequest(_:)`
- `rankedDrinks(includeHomeBrews:)`
- `tasteProfile(for:)`

## Algorithms

### ELO

Use the spec's `K_FACTOR = 32` formula. ELO logic lives in a pure helper that accepts winner and loser scores and returns updated scores.

### Pair Selection

After each new log, select uncompared drink pairs for the current user. Sort candidate pairs by absolute ELO difference ascending and show at most two rounds per session.

### Taste Profile

Taste profile computation uses the user's local logs:

- Roast counts for light, medium, and dark.
- Average sweetness and strength.
- Top flavor descriptors by count.
- Dominant flavor family.
- Identity label using the product spec rules.

## Error And Empty States

- Log save stays disabled until required fields are present.
- Flavor picker blocks selections after five and presents inline helper text.
- Home feed has an empty state when there are no visible logs.
- Shop Detail gracefully handles no logged drinks, no friends, and no chat candidates.
- Profile rankings show empty copy when the user has not logged enough drinks.

## Testing

Add focused unit tests for:

- ELO winner/loser score updates.
- Head-to-head pair selection excluding already-compared pairs.
- Taste profile averages, top flavors, and identity labels.

Manual verification should cover:

- Launching the app in an iOS simulator.
- Switching all five tabs.
- Opening shop and drink detail screens.
- Logging a drink.
- Seeing the new log appear in Home/Profile.
- Completing a head-to-head comparison and seeing ranking changes.

## Implementation Notes

Prefer native SwiftUI controls and SF Symbols. Use generated/mock initials or simple color avatars rather than remote images. Use Georgia as the heading fallback and system fonts for UI/body text until licensed brand fonts are available. Keep all first-slice data local so the prototype is useful offline and easy to run.
