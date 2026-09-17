# Reel Tycoon (working title)

A mobile fishing game for iOS + Android, built in Godot 4.

## Genre direction

Not a pure idle game, not a pure "pick a lake and hunt a checklist"
adventure game, not a pure trading-card collector -- a synthesis of the
three, where each answers a different question a player has:

- **Idle economy** (coins, rod/reel/line/lure shops, offline earnings) --
  answers "why do I open the app today." Something's always affordable or
  ready to collect.
- **Adventure structure** (pick a region, its native species are the
  point) -- answers "what am I actually doing right now." Unlocking a
  region requires BOTH a coin cost AND (for regions past the first)
  owning a card of every species native to the previous region --
  `FishingLocation.requires_complete_region`, checked by
  `GameManager.has_completed_region`.
- **Trading cards** (every catch produces a card at a rarity tier) --
  answers "what do I have to show for playing." This is also literally
  the same data that satisfies the adventure structure's "complete the
  set" gate -- one mechanic, not three separate systems bolted together.

Card rarity is a **percentile within that specific region-scoped fish's
own realistic weight range** (`Rarity.gd`), not a fixed lb scale -- a
Northern largemouth's Legendary (top of a ~12lb regional ceiling) and a
big-Southern-lake largemouth's Legendary (top of a much higher ceiling)
both mean "an exceptional catch for this water," even though the raw
numbers differ a lot.

## Core loop

Cast (tap) -> bite cue -> reel (hold-to-manage-tension mini-game) ->
catch produces coins AND a card -> spend coins on gear -> unlock the next
region (coins + that region's species-completion gate) -> repeat, now
against a new roster of native species with region-realistic sizing.

**What actually decides which fish bites**, each cast: current weather
for that region, the equipped lure's type, the equipped lure's effective
depth vs. the cast's rolled depth, and each species' (or, for some
species, each *weight class* of that species -- see `FishSizeClass.gd`)
own weather/lure/depth preferences. A picky trophy fish can realistically
ignore a bad presentation entirely. See `FishingController._roll_
candidate_catch` and `_affinity_multiplier` for the actual math.

**Weather is real for regions tied to an actual lake** (Lake Monroe,
Kentucky Lake) -- fetched live from Open-Meteo (free, no API key) for
that lake's real coordinates, so it's honestly the same for every player,
no backend of ours required (`WeatherService.gd`). Home Pond isn't a real
place, so it falls back to a local random roll.

## Monetization plan (not implemented yet)

Rewarded ads (opt-in) + IAP, not banners/interstitials. Planned
placements: 2x offline-earnings claim on return, free bait/energy refill,
skip an upgrade timer. No ad SDK is wired in -- there's no build worth
monetizing yet.

## Status -- what's built vs. what's real

**Not tested in Godot since region/weather/lure/card systems were added.**
Everything below this point in the file was hand-written without engine
access in this environment. It should be internally consistent, but
"compiles and runs in Godot" has only been confirmed for a much earlier,
simpler version of this project (rod tiers + a single pond, before
regions/weather/lures/cards existed). **Open this in Godot and playtest
before adding anything else on top** -- see "Known risk spots" below for
exactly what to check first if something doesn't load.

### Built and wired in
- Cast/bite/reel state machine (`FishingController.gd`) with rod-tier-based
  rates (`RodTiers.gd`) and region-mastery-based safe-band width
  (`FishingLocation.safe_band_width_for_mastery`) as two independent
  progression axes -- rod tier is permanent and global; region mastery
  resets to that region's own starting width on arrival.
- Three regions (`resources/locations/*.tres`): Home Pond (fictional,
  tutorial-easy), Lake Monroe IN and Kentucky Lake (both real, both with
  live weather). Roadmap for more, in the order Ryan laid out (Tennessee,
  Georgia, Canada, Texas, then saltwater/international/planetary much
  later): add a `FishingLocation.tres` + its own species `.tres` files
  the same way these three were built, and register it in `Regions.gd`.
- Region-scoped `Fish` resources with realistic weight ranges, a skewed
  rarity-of-size roll (`pow(randf(), size_skew)` -- big fish are
  exponentially rare, not uniformly likely), and weather/lure/depth
  preferences (flat per-species, or per-weight-class via
  `FishSizeClass.gd` where a trophy specimen should behave differently
  than an average one).
- Lures (`resources/lures/*.tres`, all original names, no real brands) --
  `type` and `effective_depth_ft` affect bite odds; `color`/`size` are
  real, ownable, displayed attributes that don't affect odds yet.
- Card collection (`GameManager.cards`) + region-completion gate.
- A local-only leaderboard (`LeaderboardService.gd`) that's honest about
  not comparing to real other players yet.
- A tabbed menu (Rod / Region / Lures / Records / Ranks) built almost
  entirely in code (`scripts/ui/*.gd`) rather than hand-placed scene
  nodes, so new regions/lures/cards show up automatically.
- Placeholder visuals with no real art yet: a two-tone drawn bobber, a
  static rod + dynamic fishing line (`Line2D`), a reel wheel that spins
  while reeling, a simple sky/water/shoreline backdrop tinted per region.

### Data modeled but NOT wired into gameplay yet
- **Tackle**: `GameManager` has fields for reel type (push-button /
  spinning / baitcaster), line type (mono / fluoro / braided), and line
  weight (lb test) -- Ryan's ask was push-button = higher snap-off risk,
  spinning/baitcaster each better for different lure types/techniques,
  line type trading off stretch-forgiveness vs. sensitivity, heavier line
  handling big fish but spooking line-shy species. None of this affects
  `FishingController` yet -- there's no `ReelTypes.gd`/`LineTypes.gd`
  data table, no snap-chance mechanic, no UI to equip any of it. The
  fields just save/load harmlessly in the meantime.
- **Polarized glasses / sight-fishing**: `GameManager.owns_polarized_
  glasses` exists as a field, but the actual mechanic (roll the candidate
  fish earlier, at the start of the wait rather than at hook-time; show a
  size-bucketed shadow -- small/medium/large/trophy, never an exact
  weight -- swimming toward the bobber shortly before the bite; let an
  ignored bite double as "I let that one go") is designed but not built.
  No `fish_sighted` signal, no shadow visual, no purchase UI yet.

### Known risk spots to check first if Godot reports an error on load
Everything below is hand-written Godot 4 syntax that's *believed*
correct but unverified by an actual compile:
1. Typed-array-of-custom-Resource syntax in `.tres` files, e.g.
   `species = Array[Resource]([ExtResource("2"), ...])` (all region
   files) and `size_classes = Array[Resource]([SubResource(...), ...])`
   (`northern_largemouth_bass.tres`, `northern_smallmouth_bass.tres`).
2. Typed-array-of-StringName literals in `.tres`, e.g.
   `preferred_weather = Array[StringName]([&"rainy"])`.
3. Local `const` declared inside a function body (`Weather.gd`'s
   `from_open_meteo`).
4. `HTTPRequest` usage in `WeatherService.gd` -- untested against a real
   Open-Meteo response shape.

If any of these turn out to be wrong, the fix is usually small and
localized (once Godot's error message says which line) -- flagging them
so a first-load error isn't a surprise.

## Running it

Open this folder in Godot 4.3+ (tested by Ryan on 4.7) and press Play --
`project.godot` points `run/main_scene` at `FishingScene.tscn`. Tap
**Cast**, wait for "BITE!", tap again to hook it, then hold the button to
keep the white tension marker inside the green band until the orange
progress bar fills. Tap **Menu** to reach the rod shop, region travel/
mastery, lure shop, card binder, and leaderboard tabs.

## Next steps

1. **Playtest in Godot now** -- see "Known risk spots" above.
2. Build out the tackle system (reel/line type + weight) that's currently
   just inert `GameManager` fields.
3. Build the polarized-glasses sight-fishing mechanic.
4. Source real placeholder art from [Kenney.nl](https://kenney.nl) to
   replace the flat-color/drawn-shape visuals.
5. Add more regions following the roadmap order above.
6. A real backend for the leaderboard (weather doesn't need one anymore --
   see WeatherService.gd's header -- but real cross-player comparison
   still does). Could reuse the Go/MariaDB pattern from `portfolio-api`.
7. Rewarded-ads SDK integration once there's a build worth monetizing.
8. Android (Google Play Console) / iOS (Apple Developer Program) accounts
   + export presets for real device builds. Note: a real device build
   will need the Android INTERNET permission for `WeatherService`'s
   HTTP requests to work -- the Godot editor doesn't need this, but an
   exported APK will.
