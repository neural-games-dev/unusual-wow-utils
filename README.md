# Unusual WoW Utils

This add-on is a collection of utils to improve your WoW playing experience.

By default, all of the utils are enabled, but you can disable specific utils using the settings window.

## Included Utils

### Auto Dungeon Queue

Quickly enter dungeon queues at the press of a keybind or with a slash command.

- `/adq` opens or closes the Dungeon Finder.
- `/adq join` queues you for a random dungeon with your saved roles, without opening any windows. If you have no saved roles yet, it opens the Dungeon Finder so you can pick them. Also available as a keybinding.
- `/adq leave` leaves the dungeon queue. Also available as a keybinding.
- `/adq save <tank|healer|DPS>` saves your role(s), e.g. `/adq save tank DPS`. It also ticks the matching boxes in the Dungeon Finder. Roles your class can't fill are rejected.
- `/adq save` saves whichever roles are currently ticked in the Dungeon Finder.
- `/adq roles` shows your saved roles.
- `/adq clear` clears your saved roles and unticks them in the Dungeon Finder (also available as a keybinding), so the next `/adq join` opens the Dungeon Finder to pick them again.
- `/adq help` lists the commands.

### Chat Tab Cycler

Just like your web browser, cycle through your chat tabs going forward AND backward, genius!

Yes, there is a default keybind to go to the next tab, BUT... it only goes forward!

This util allows you to go whichever direction your heart desires, PLUS, it has better highlighting of which tab is actually active!

### Combat Interface Manager

Hides UI elements (chat, minimap, quest tracker) when you enter combat and restores them when you leave. Options: `/cim`

### Cooldown Bar Global

A customizable bar to visually track the global cooldown. Options: `/cbg`

Use `/cbg move` to toggle 'Move' mode, which keeps the bar visible so you can drag it into place.

> [!NOTE]
>
> This util is a resurrection of an add-on that I used many moons ago, originally created by **Radagast7**.
>
> If you have a link to the original (e.g. an old GitHub or CurseForge page), please post a message & share it, and I'll properly link to it here.

### Quest Log Counter

A counter showing how many quests you have in your log. It's docked to the quest log and follows it when you move the quest log in Edit Mode. Type `/qlc` to open its options, where the Positioning tab picks where it docks: left of the quest log (the default, tops aligned), right of it (tops aligned), on top of it, or below it (left edge just past the quest log's). The Style tab picks its border & background from the game's own UI textures. These choices are remembered across reloads. It's locked in place; hold Shift and left-click drag to move it on its own, and use `/qlc reset` (or the Reset Position button) to put it back in its docked position.

Use `/qlc hide` and `/qlc show` to hide or show the counter (remembered across reloads). If Combat Interface Manager is set to hide the quest log in combat, the counter hides along with it, and these commands have no effect.

## Enabling & Disabling Utils

Open the settings with `/uwu` (or find "Unusual WoW Utils" under Options > AddOns) and toggle each util. Changes take effect after a `/reload`.

Type `/uwu help` to list the slash commands for UwU and all of its utils.

Combat Interface Manager, Cooldown Bar Global, and Quest Log Counter were previously standalone add-ons. If a standalone copy is still loaded, the matching util here is skipped so they don't clash. Disable the standalone add-on to use the bundled one.

## Future To-Do

### Auto Dungeon Queue: leave an instance (`/adq exit`)

Add an `/adq exit` command (and keybinding) to get out of a dungeon you're already inside. There's no single "exit this instance" API, but these cover the common cases:

| API                              | What it does                                                                                                                                                                        |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LFGTeleport(true)`              | Teleports you out of a Dungeon Finder dungeon but keeps you in the group (the same as "Teleport out of Dungeon" in the queue eye menu). `LFGTeleport(false)` teleports you back in. |
| `C_PartyInfo.LeaveParty()`       | Leaves your group. Inside an instance, the game then ports you out after a short grace timer. Works for any group instance.                                                         |
| `LeaveInstanceParty()`           | Leaves the instance group specifically, for when you're in both a normal party and a Dungeon Finder group at once.                                                                  |
| `C_PartyInfo.DelveTeleportOut()` | Teleports out of a Delve.                                                                                                                                                           |
| `LeaveBattlefield()`             | Leaves a battleground or arena.                                                                                                                                                     |

Helpers for deciding which one applies:

- `IsInInstance()` returns whether you're in an instance and its type (party, raid, pvp, arena, scenario).
- `IsInLFGDungeon()` and `IsPartyLFG()` tell you whether it's a Dungeon Finder dungeon or group.

Planned behavior: use `LFGTeleport(true)` in a Dungeon Finder dungeon, which gets you out without leaving the group. `C_PartyInfo.LeaveParty()` could back a separate "leave everything" option.

Open question: whether any of these require a hardware event (a direct key press or click). A slash command or keybinding counts as one, so those paths should be fine.
