# Atlas Custom Scoreboard

A [Northstar](https://northstar.tf/) client-side mod that replaces Titanfall 2's multiplayer scoreboard with a custom one - more stat columns than vanilla allows, fully configurable per gamemode. 100% client-side, works on any server.

## Contact me!

If you need any help with anything, or have questions, or complaints, or suggestions, or ANYTHING AT ALL, contact me on discord at `atlas_418`. Please, I want more friends. 

## Requirements

- [Northstar](https://northstar.tf/)

## Incompatibilities

Assume any mods that mess with the scoreboard are not compatable with this. If you really want a mod to be compatable contact me about it and I'll see what I can do.

## Installation

Drop the `Atlas418.CustomScoreboard` folder into your Northstar `packages` folder (e.g. `titanfall2/R2Northstar/packages/`, or the equivalent folder for whichever profile/launch setup you use).

## AI Usage PSA

Claude Code was used quite a bit in the making of this project. I have written a solid chunk of the code by hand, and everything made by AI has been reviewed.

I would not call this mod slop, but I understand if you do. 

My hope is to do a full rewrite by hand now that I know how to make everything functional. No idea when / if that will come, but if it does, this version will be replaced. 

I did kinda let it do it's thing with the code comments, but this doc was written by me. Next update will be me going through all the code, and rewriting all the comments so they're not absurdly verbose.

I am NOT pro-AI, though I do believe it can be helpful as a tool. Like I used it here.

**tldr**: Don't call me a no skill AI bro pls, I promise I commision artists and know how to write code

## Usage

On mod install, behaviour of the vanilla scoreboard is mimiced, but with this scorebaord's style, so some text wraps wrong and whatnot. It does work though!

To use custom configs, you need to put said configs (like the one that ships with this mod) into `R2Northstar/save_data/Atlas418.CustomScoreboard/scoreboard_settings.json`.

## Configuration

Optional, local-only JSON file. Not neccecary.

- `settings` - object, applies everywhere (not per-gamemode)
  - `rowHeight` - int, row height in pixels. Default `22`, clamped `12`-`60`.
  - `rowSpacing` - int, pixels between rows. Default `2`, clamped `0`-`40`.
  - `columnGap` - int, pixels between column boxes (name column included). Default `6`, clamped `0`-`40`.
  - `centered` - bool, default `false`. `false` = right-anchored (default), `true` = horizontally centered. Always vertically centered regardless.
  - `colors` - object, `"name": [r,g,b]` or `[r,g,b,a]` (each 0-255, alpha optional, default `160`). Any key names you want - referenced by name from any color field below.
- `columnPresets` - array of objects, top-level (**not** nested under `settings`). Reusable named columns - reference one from any gamemode's `columns` by name instead of repeating it inline.
  - `name` - string, required. What `columns` entries reference to use this preset.
  - *(the rest of the fields below - `title`/`stat`/`width`/color fields - same as a `columns[]` entry)*
- `<GAMETYPE>` - object, one per gamemode you want to override (e.g. `"aitdm"`, `"tdm"`, `"at"` - raw GAMETYPE string, not a display name). Anything omitted falls back to vanilla's default for that gamemode.
  - `sortMode` - object
    - `stat` - string, a `PGS_*` stat name or one of the sentinels below (same accepted values as `columns[].stat`). Unrecognized name -> warning + falls back to `PGS_KILLS`.
    - `descending` - bool. Default `true`.
    - `teamsSplit` - bool. Default `false`. Groups the list into team blocks (your team first) instead of one flat ranking.
  - `columns` - array, up to 12 entries total (name column included). Each entry is either:
    - a string - the `name` of a `columnPresets` entry, used exactly as defined there, or
    - an object:
      - `title` - string, shown verbatim (not localized). Omit/empty = no header shown above this column.
      - `stat` - string, one of the values in the list below.
      - `width` - int, **characters** (not pixels - monospace font). Default `8`. Ignored on `"NAME"` (always auto-sized to the longest shown name).
      - `background` - string (a `settings.colors` key) or `[r,g,b]`/`[r,g,b,a]`. Shorthand for the 4 fields below - sets all of them unless overridden individually. Default: fully transparent, `[0,0,0,0]`.
      - `backgroundSelf` - same value shape. Background when this row is you.
      - `backgroundParty` - same value shape. Background for a party member on your team (an enemy-team party member still resolves to `backgroundEnemy`).
      - `backgroundFriendly` - same value shape. Background for a teammate (not self, not party).
      - `backgroundEnemy` - same value shape. Background for anyone not on your team.
      - `text` - same value shape as `background`. Shorthand for the 4 text fields below. Default white.
      - `textSelf` / `textParty` / `textFriendly` / `textEnemy` - same value shape, same self/party/friendly/enemy split as the background fields above, but for the label's text color.

### Gamemodes:

Not all gamemodes are listed here See the [Northstar docs](https://docs.northstar.tf/Wiki/hosting-a-server-with-northstar/server-settings/file-names/) page on this for all the gamemodes.

| Playlist | Title |
| --- | --- |
| `aitdm` | Attrition |
| `at` | Bounty Hunt |
| `coliseum` | Coliseum |
| `cp` | Amped Hardpoint |
| `ctf` | Capture the Flag |
| `lts` | Last Titan Standing |
| `ps` | Pilots vs. Pilots |
| `tdm` | Skirmish |
| `ttdm` | Titan Brawl |
| `lf` | Live Fire |
| `ffa` | Free For All |


### usable stats:

| Value | Description |
|---|---|
| `NAME` | Shows the player's name instead of a stat |
| `PGS_GEN` | Generation/prestige (1-10) |
| `PGS_AD` | Assault score over deaths. This is a custom score I made as I wanted a way to sort attrition games that takes deaths into account. |
| `PGS_KILLS` | Generic kill count (modes that don't split pilot/titan kills) |
| `PGS_PILOT_KILLS` | Pilots killed |
| `PGS_TITAN_KILLS` | Titans killed |
| `PGS_DEATHS` | Death count |
| `PGS_ASSISTS` | Assist count |
| `PGS_PING` | Player's connection ping |
| `PGS_ELIMINATED` | 0/1 flag - still alive, mainly for LTS-style modes |
| `PGS_NPC_KILLS` | Grunt/spectre/AI kills (AI TDM only) |
| `PGS_ASSAULT_SCORE` | Generic scoring slot - meaning depends on gamemode (e.g. Score in Attrition, Assault in Hardpoint) |
| `PGS_DEFENSE_SCORE` | Generic scoring slot - meaning depends on gamemode (e.g. Defense in Hardpoint, Returns in CTF) |
| `PGS_SCORE` | Generic scoring slot - meaning depends on gamemode (e.g. Bonus in Attrition) |
| `PGS_DETONATION_SCORE` | Generic scoring slot - meaning depends on gamemode (e.g. Total in Frontier Defense) |
| `PGS_DISTANCE_SCORE` | Generic scoring slot - meaning depends on gamemode (e.g. Titan Damage in CTF Comp) |

Not sure what a gamemode actually shows? Leave `columns` unset for it and it'll fall back to showing whatever vanilla's own scoreboard would. Or ask me. You can always ask me.

## Other files in this directory

- `scoreboard_settings.json`
  - The config for this mod that I personally use. I think it's a good starting place, and frankly I quite like it.
- `link_settings.bat`
  - This is a batch script that will make a link between the settings file here, and where the settings file should be for it to load properly. This can be run instead of moving the file manually, and then editing the settings file here will update the mod settings.
- `gen_hudscoreboard_patch.py`
  - A script that claude made to autogenerate the resource file (`hudscoreboard.res`) from the code. I don't know what goes on in there yet, but it's next up for review.

## What can't it do?

- Icons
  - as this uses VGUI in place of the RUI rendering of the vanilla scoreboard, we can't draw icons.
  - might do some black magic fuckery some day, but not today.
- Titan damage in attrition
  - I hope to figure it out some day, but as of right now I just don't know how to track it.
- Look bad
  - you fucking know it, this is beautiful, and it's definitely not just me glazing my creation.

## Credits

- Claude Code was used quite a bit in the making of this project. I have written a solid chunk of the code by hand, and everything made by AI has been reviewed. 
- Very loosely based on Khalmee's `ScoreboardCallbacks` mod.
- Font: [JetBrains Mono](https://www.jetbrains.com/lp/mono/) NL Regular, bundled under the SIL Open Font License (see `Mod/resource/jetbrainsMono-OFL.txt`).
