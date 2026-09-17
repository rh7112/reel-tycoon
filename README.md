# Reel Tycoon (working title)

An idle/casual mobile fishing game for iOS + Android, built in Godot 4.
Genre reference points: *Hooked Inc: Fisher Tycoon*, *Fishing Clash*,
*Ridiculous Fishing* -- proven "addicting loop" mechanics, not a new
mechanic invented from scratch.

## Core loop

Cast (tap, one-handed) -> bite cue -> reel (hold-to-manage-tension
mini-game) -> fish auto-sells for coins scaled by species rarity and rolled
size -> spend coins on rod/line/bait upgrades -> unlock the next location
(pond -> lake -> river -> ocean -> deep sea) with new species -> repeat.

Retention hooks layered on top of the moment-to-moment loop (not yet all
implemented -- see Status below):
- **Idle/offline earnings** -- the main reason a player opens an idle game
  daily. Capped at 8h (`GameManager.MAX_OFFLINE_SECONDS`) so a long absence
  doesn't trivialize the "come back tomorrow" incentive.
- **Fish almanac/collection** -- `GameManager.fish_caught` tracks every
  species ever landed; a completion screen is the natural next UI to build
  on top of it.
- **Daily login streak + quests**, **prestige/reset layer** for long-term
  players once a location/gear tier maxes out -- neither started yet.

## Monetization plan

Rewarded ads (opt-in, not forced) + IAP, not banners/interstitials --
rewarded placements don't hurt retention the way forced ad formats do, and
they're the format that actually converts to real revenue in this genre.

Planned placements:
- 2x the offline-earnings claim on return (single highest-converting spot
  in idle games)
- Free bait/energy refill
- Skip an upgrade-crafting timer

IAP on top: currency packs, cosmetic rods/boats, a "double all future
rewarded-ad bonuses" permanent purchase (feels generous, isn't pay-to-win).
No ad SDK is wired in yet -- see Next steps.

## Status / what's actually built

This is a first playable prototype of **only the riskiest part**: does the
cast -> bite -> reel loop feel good at all. Everything else (economy
depth, upgrades, multiple locations, art, monetization) is deliberately
not built yet, on purpose -- no point investing in the rest if the core
tap/hold interaction isn't fun to repeat.

- `scripts/entities/FishingController.gd` -- the cast/wait/bite/reel state
  machine. Tune `SAFE_BAND`, `TENSION_RISE_RATE`, `TENSION_FALL_RATE`,
  `PROGRESS_FILL_RATE`, `BITE_REACTION_WINDOW` here first when playtesting
  feel -- these five constants are the entire feel of the game right now.
- `scripts/entities/Fish.gd` / `FishingLocation.gd` -- data-only Resources,
  so adding a species or a location is a `.tres` file, not a code change.
- `scripts/autoload/Economy.gd` -- coins/gems, signal-driven for UI.
- `scripts/autoload/GameManager.gd` -- gear tier, unlocked locations, fish
  almanac, offline-earnings calculation.
- `scripts/autoload/SaveManager.gd` -- plain JSON to `user://save.json`.
  No schema versioning yet -- add it once the save shape stops changing
  weekly.
- `scenes/FishingScene.tscn` -- placeholder UI (flat-color rects, no art)
  wired to the above via `FishingHUD.gd`. One starter location (`pond`)
  with three species (`resources/fish/*.tres`).

## Running it

Open this folder in Godot 4.3+ and press Play -- `project.godot` already
points `run/main_scene` at `FishingScene.tscn`. Tap **Cast**, wait for
"BITE!", tap again to hook it, then hold the button to keep the white
tension marker inside the green band until the orange progress bar fills.

## Next steps

1. **Playtest the reel mini-game feel** and retune the five constants
   above before building anything else on top -- this is the whole point
   of building this piece first.
2. Source real placeholder art from [Kenney.nl](https://kenney.nl) (free,
   no attribution required) to replace the flat-color rects.
3. Build the shop/upgrade screen against `Economy` + `GameManager.rod_tier`.
4. Add a second location + species roster once the loop feels right, to
   prove out the "data-only" unlock pattern end to end.
5. Wire up a rewarded-ads Godot plugin (AdMob is the standard choice) once
   there's an actual build worth monetizing -- no point integrating an ad
   SDK before there's a loop worth watching an ad for.
6. Set up Android (Google Play Console) and iOS (Apple Developer Program)
   accounts + Godot's export presets when ready for real device builds.
