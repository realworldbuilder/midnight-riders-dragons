# Midnight Riders Dragons

A World of Warcraft: Forever addon for the **<Midnight Riders>** guild.

- **Guild master:** a gold dragon around their portrait.
- **Officers:** a silver dragon.

You'll see the dragons on your own frame, your party frames, and whoever you target or focus.

## Install

Copy one line, paste it, press Enter.

### Windows

Open **PowerShell** (press the Windows key, type `powershell`, press Enter) and paste:

```powershell
irm https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.ps1 | iex
```

### Mac

Open **Terminal** (press Cmd+Space, type `terminal`, press Enter) and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.sh | bash
```

Then **restart the game**. On the character screen, click **AddOns** and make sure **Midnight Riders Dragons** is ticked. Type `/mrdragon` in game to check it's working.

**To update,** paste the same line again. It replaces the old version.

The command finds your Forever folder on its own, downloads the latest version from this page, and puts it in `_forever_/Interface/AddOns`. It doesn't touch anything else. You can read exactly what it does in [install.ps1](install.ps1) and [install.sh](install.sh).

<details>
<summary><strong>It says it can't find Forever, or isn't allowed to write there</strong></summary>

- **Can't find Forever:** tell it where your `World of Warcraft` folder is (the one with `_forever_` inside).
  - Windows: `$env:WOW_DIR = 'D:\Games\World of Warcraft'; irm https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.ps1 | iex`
  - Mac: `curl -fsSL https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.sh | WOW_DIR="/path/to/World of Warcraft" bash`
- **Not allowed to write (Windows):** close the game, right-click PowerShell, choose **Run as administrator**, and paste the line again.

</details>

<details>
<summary><strong>Install by hand instead</strong></summary>

1. Download [MidnightRiders_Dragons.zip](https://github.com/realworldbuilder/midnight-riders-dragons/releases/latest/download/MidnightRiders_Dragons.zip).
2. Unzip it, and put the `MidnightRiders_Dragons` folder inside `World of Warcraft/_forever_/Interface/AddOns/`. If there's no `AddOns` folder, make one.
3. Check the folder: it should be `AddOns/MidnightRiders_Dragons/Dragons.lua`, not one folder deeper.

</details>

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
