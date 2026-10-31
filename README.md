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

Hides UI elements (chat, minimap, quest tracker) when you enter combat and restores them when you leave. It can also switch to one of your saved camera views (the "Set View 1-5" keybindings) when you enter and/or leave combat, and when you mount and/or dismount. Options: `/cim`

### Compass

A flight HUD that shows which way you're heading. A ring of compass points rotates around a fixed arrow as you turn, with your heading in degrees in the middle. It starts centered on the screen with a semi-transparent, rounded background. Options: `/compass`

The Style option picks the look: Bars (the default), a horizontal strip of bars that slides sideways as you turn, showing 3 bars on either side of your heading, or Dial. Use the options to change the scale and the background's color & opacity. Hold Shift and left-click drag to move it, and use `/compass reset` to re-center it. Bind a key to toggle it in Key Bindings (unassigned by default), or use `/compass toggle`, `/compass show` and `/compass hide`.

### Cooldown Bar Global

A customizable bar to visually track the global cooldown. Options: `/cbg`

Use `/cbg move` to toggle 'Move' mode, which keeps the bar visible so you can drag it into place.

> [!NOTE]
>
> This util is a resurrection of an add-on that I used many moons ago, originally created by **Radagast7**.
>
> If you have a link to the original (e.g. an old GitHub or CurseForge page), please post a message & share it, and I'll properly link to it here.

### Obvious Statuses

Shows up to three statuses as a stack of rectangles, in your faction's color. From bottom to top: combat ("Fighting" or "Roaming"), dragonriding ("Dragon" when Skyriding is on, else "Steady"), and the zone's phase ("Past" or "Present", for zones where Zidormi can send you back in time). Options: `/os`

The dragonriding and phase rectangles can each be hidden while you're in combat, and the phase one can optionally always show "Present" outside of Zidormi's zones. Hold Shift and left-click drag to move it, or use the Positioning tab.

It also has a range indicator: a separate square that shows whether your target is in range of a spell you name on the Range tab. An open eye under a green tint means it's in range, and a closed eye under a red tint means it's too far away. With no target (or one the spell can't be cast on), it shows the spell's icon, greyed out. If no spell by that name is found, it shows the red question mark. It's hidden while no spell is named. The Range tab also sets its scale and position, and you can hold Shift and left-click drag it on its own.

Zidormi has no API, so the phase status only works in zones listed in `PHASE_ZONES` in `Modules/ObviousStatuses/ObviousStatuses.lua`. Stand in a zone, in the past and in the present, and use `/os debug` to find the values to add.

### Quest Log Counter

A counter showing how many quests you have in your log. It's docked to the quest log and follows it when you move the quest log in Edit Mode. Type `/qlc` to open its options, where the Positioning tab picks where it docks: left of the quest log (the default, tops aligned), right of it (tops aligned), on top of it, or below it (left edge just past the quest log's). The Style tab picks its border & background from the game's own UI textures, plus any that your other add-ons share through LibSharedMedia (listed after the built-in ones). These choices are remembered across reloads. It's locked in place; hold Shift and left-click drag to move it on its own, and use `/qlc reset` (or the Reset Position button) to put it back in its docked position.

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
