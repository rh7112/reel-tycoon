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
own realistic weight range** (`CardRarity.gd`), not a fixed lb scale -- a
Northern largemouth's Legendary (top of a ~12lb regional ceiling) and a
big-Southern-lake largemouth's Legendary (top of a much higher ceiling)
both mean "an exceptional catch for this water," even though the raw
numbers differ a lot.

## Core loop

Cast -> wait for a bite -> hook it -> reel (hold-to-manage-tension
mini-game) -> catch produces coins AND a card -> spend coins on gear ->
unlock the next region (coins + that region's species-completion gate)
-> repeat, now against a new roster of native species with
region-realistic sizing.

The wait/hook step forks by equipped lure (`Lure.presentation_style`,
see `FishingController.get_current_style`):
- **Bobber** (worm, dough-ball catfish bait): passive -- cast it and
  wait, tap to bring it in early if a spot isn't producing, tap again
  when it bites to hook.
- **Retrieve** (spinner/crankbait/jerkbait/topwater): active -- hold
  the button to reel it in; the wait only counts down while held. A
  strike only becomes a hookset if you actually release and tap again
  -- continuing to hold through it does nothing, on purpose (Godot's
  button-down signal only fires on a fresh press).

Depth is a player choice (a +/- stepper, clamped to the region's real
range), not randomized -- the water visibly darkens as you fish deeper.
The tension/progress bars stay hidden until something's actually on the
hook.

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
- Tackle (`ReelTypes.gd`/`LineTypes.gd`) -- reel type (push-button/
  spinning/baitcaster) and line type (mono/fluoro/braided) are owned/
  equipped like lures, not a linear upgrade ladder. Push-button carries
  its own snap-off risk; baitcaster pairs best with heavier lure types
  (crankbait/jerkbait), spinning with lighter ones -- a real tradeoff,
  not "baitcaster is strictly better." Line weight (lb test) is a free
  choice: heavier handles a big fish without snapping, but is more
  visible to line-shy species. All wired into
  `FishingController._tick_reel`/`_affinity_multiplier`. Equip from the
  "Gear" menu tab (`RodPanel.gd`).
- Card collection (`GameManager.cards`) + region-completion gate.
- A local-only leaderboard (`LeaderboardService.gd`) that's honest about
  not comparing to real other players yet.
- A tabbed menu (Rod / Region / Lures / Records / Ranks) built almost
  entirely in code (`scripts/ui/*.gd`) rather than hand-placed scene
  nodes, so new regions/lures/cards show up automatically.
- Placeholder visuals with no real art yet: a two-tone drawn bobber, a
  static rod + dynamic fishing line (`Line2D`), a reel wheel that spins
  while reeling, a simple sky/water/shoreline backdrop tinted per region.

Starting gear is a push-button reel + a worm-on-a-bobber rig, both
owned/equipped by default -- matches how most people actually start,
and everything else (other reel types, every other lure) is something
to unlock rather than a blank slate.

### Data modeled but NOT wired into gameplay yet
- **Polarized glasses / sight-fishing**: `GameManager.owns_polarized_
  glasses` exists as a field, but the actual mechanic (roll the candidate
  fish earlier, at the start of the wait rather than at hook-time; show a
  size-bucketed shadow -- small/medium/large/trophy, never an exact
  weight -- swimming toward the bobber shortly before the bite; let an
  ignored bite double as "I let that one go") is designed but not built.
  No `fish_sighted` signal, no shadow visual, no purchase UI yet.

### Backlog
Tracked as GitHub issues from here on rather than duplicated in this
file -- see [the issue tracker](https://github.com/rh7112/reel-tycoon/issues)
for the current list (sight-fishing, consumable lure economy + snag
risk, catch confirmation popup, sponsorships, rod/reel visual overhaul,
more regions, real art, the leaderboard backend, ads/IAP, store/export
setup). Each is closed via the commit that implements it.

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

**Bugs already found and fixed, live** (each confirmed by an actual
Godot error, not guessed):
- A global `class_name` and a nested `enum` of the same bare name
  collide -- the card rarity system was originally also named `Rarity`,
  shadowing `Fish.gd`'s own pre-existing `enum Rarity` (an unrelated,
  older concept) every time `Fish.gd` wrote `Rarity.COMMON`. Renamed to
  `CardRarity`. If Godot ever reports "Cannot assign a value of type
  X.Y to variable ... with specified type Y" again, check for this
  exact pattern first.
- `var x := ... * some_dict.field` uses type inference (`:=`), but a
  `Dictionary` field access is untyped `Variant` to the static
  analyzer, even though it's a float at runtime -- inference fails with
  "Cannot infer the type of ... because the value doesn't have a set
  type." Fix is an explicit `var x: float = ...` instead of `:=`
  wherever a Dictionary-sourced value (from `RodTiers.gd`/
  `ReelTypes.gd`/`LineTypes.gd`, all plain-Dictionary tables) is
  combined arithmetically.
- `FishingHUD._on_action_button_down` never forwarded presses during
  `WAITING_FOR_BITE` to the controller at all -- silently meant neither
  the bobber's "tap to bring it in early" nor the retrieve style's
  "hold to reel" could ever fire, with no error to catch it. Worth
  double-checking any new state gets wired into *both*
  `FishingController`'s logic and `FishingHUD`'s input forwarding --
  this class of bug (a state that logic handles but no button ever
  routes input to) produces no error at all, just a control that
  silently does nothing.

## Running it

Open this folder in Godot 4.3+ (tested by Ryan on 4.7) and press Play --
`project.godot` points `run/main_scene` at `FishingScene.tscn`. Use the
+/- buttons to pick a depth, tap **Cast**, then it depends on the
equipped lure (worm-on-a-bobber by default): wait for "BITE!" and tap
to hook it, or tap again anytime first to bring it in early. Once
hooked, hold the button to keep the white tension marker inside the
green band until the orange progress bar fills -- these bars only
appear once something's on. Tap **Menu** to reach the gear shop
(rod/reel/line), region travel/mastery, lure shop, card binder, and
leaderboard tabs.

## Next steps

**Playtest in Godot now** -- see "Known risk spots" above. Everything
else worth doing next is in the [issue tracker](https://github.com/rh7112/reel-tycoon/issues),
not this file.
