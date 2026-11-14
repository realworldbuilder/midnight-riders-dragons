# Midnight Riders Dragons

A World of Warcraft: Forever addon for the **<Midnight Riders>** guild.

- **Guild master:** a gold dragon around their portrait.
- **Officers:** a silver dragon.

You'll see the dragons on your own frame, your party frames, and whoever you target or focus.

## Install

1. **Download:** [MidnightRiders_Dragons.zip](https://github.com/realworldbuilder/midnight-riders-dragons/releases/latest/download/MidnightRiders_Dragons.zip)
2. **Unzip it** and put the `MidnightRiders_Dragons` folder inside your Forever AddOns folder:
   - **Windows:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - **Mac:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`

   No `AddOns` folder? Make one inside `Interface`.
3. **Restart the game.** On the character screen, click **AddOns** and make sure **Midnight Riders Dragons** is ticked.

That's it. Type `/mrdragon` in game to check it's working.

**Check the folder:** it should be `AddOns\MidnightRiders_Dragons\Dragons.lua`. If you see `AddOns\MidnightRiders_Dragons\MidnightRiders_Dragons\…`, it's one folder too deep. Move the inner folder up a level.

**Updating:** download the zip again, delete the old `MidnightRiders_Dragons` folder, and unzip the new one in its place.

## Commands

| Command | Does |
| --- | --- |
| `/mrdragon` | Shows who has a dragon right now: you, your target, your focus, your party |
| `/mrdragon ranks` | Lists every guild rank and which dragon it gets |
| `/mrdragon on` / `off` | Turns all dragons on or off |
| `/mrdragon player` / `target` / `focus` / `party` | Turns one kind of frame on or off |
| `/mrdragon test gold` / `silver` / `off` | Previews a dragon on your own frame |
| `/mrdragon nudge 2 -1` | Moves your own dragon a few pixels (`nudge reset` puts it back) |

## How it knows who's who

- **In the guild:** it reads the guild roster. Officers are the ranks with "officer privileges" ticked in the guild's rank settings, so promotions show up on their own.
- **Not in the guild:** it goes by what the game shows about each player's guild and rank.

Nothing is sent between players, and it doesn't touch your other addons. It uses Forever's own dragon art, the same art the game uses for elite and rare monsters.

## Problems?

Ask in the guild Discord, or [open an issue](https://github.com/realworldbuilder/midnight-riders-dragons/issues). Paste what `/mrdragon` prints in chat.

For a deeper look: type `/mrdragon debug`, then `/reload`. The addon saves what the game reported into `WTF/Account/<your account>/SavedVariables/MidnightRiders_Dragons.lua`. Type `/mrdragon debug` again to turn it off.

---

Part of the Midnight Riders addons, alongside [Midnight Riders Meter](https://github.com/realworldbuilder/midnight-riders-addons). MIT licence. A fan project, not made by or affiliated with Blizzard Entertainment.
