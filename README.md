# Unusual WoW Utils

This add-on is a collection of utils to improve your WoW playing experience.

By default, all of the utils are enabled, but you can disable specific utils using the settings window.

## WoW Forever

The add-on also works on WoW Forever, from the same folder. Forever has no Dungeon Finder queue, no flying and no Zidormi, so anything that needs them works differently or is hidden there:

- Auto Dungeon Queue lists you in the Looking for Group window instead of queueing you (see its section).
- Obvious Statuses only shows the combat status and the range indicator. The flight and phase statuses, and the options for arranging several statuses, are hidden.
- Mobile Banking Timer only shows up for characters who know the Mobile Banking guild perk.

## Included Utils

### Auto Dungeon Queue

Quickly enter dungeon queues at the press of a keybind or with a slash command. On WoW Forever, which has no Dungeon Finder queue, it lists you in the Looking for Group window instead (see below).

- `/adq` opens or closes the Dungeon Finder.
- `/adq join` queues you for a random dungeon with your saved roles, without opening any windows. If you have no saved roles yet, it opens the Dungeon Finder so you can pick them.
- `/adq leave` leaves the dungeon queue.
- The "Join/Leave Queue" keybinding does both: it leaves the queue if you're waiting in it, and joins otherwise.
- `/adq save <tank|healer|DPS>` saves your role(s), e.g. `/adq save tank DPS`. It also ticks the matching boxes in the Dungeon Finder. Roles your class can't fill are rejected.
- `/adq save` saves whichever roles are currently ticked in the Dungeon Finder.
- `/adq roles` shows your saved roles.
- `/adq clear` clears your saved roles and unticks them in the Dungeon Finder (also available as a keybinding), so the next `/adq join` opens the Dungeon Finder to pick them again.
- `/adq help` lists the commands.

On WoW Forever, the same commands and keybindings (a "List/Delist" one that delists you if you're listed and lists you otherwise, plus "Clear Saved Roles") work through the Looking for Group window's Create Listing tab, without opening it:

- `/adq join` lists you for dungeons with your saved roles. The roles are your Create Listing role check boxes, so ticking them there saves them too. Forever's listings have no leader role.
- Which dungeons it lists you for is set in its options window (`/adq`, or the cog in `/uwu`): **All dungeons for my level** (every dungeon whose suggested levels fit yours, the default) or **My last listing's dungeons** (the dungeons you ticked the last time you listed yourself in Create Listing). The same window has a **Playstyle** dropdown (Create Listing's choices, or None to list without one).
- `/adq leave` removes your listing. It also clears the Browse tab's search results, which would otherwise keep showing your listing as delisted; search again to fill them back in.

### Chat Tab Cycler

Just like your web browser, cycle through your chat tabs going forward AND backward, genius!

Yes, there is a default keybind to go to the next tab, BUT... it only goes forward!

This util allows you to go whichever direction your heart desires, PLUS, it has better highlighting of which tab is actually active!

It also has "Go To Tab 1" through "Go To Tab 10" keybindings to jump straight to a tab. Tabs are numbered by where they sit in the chat dock, from left to right, so dragging a tab to a new spot changes its number. Floating (undocked) chat windows aren't counted.

### Combat Interface Manager

Hides UI elements (chat, minimap, quest tracker) when you enter combat and restores them when you leave. It can also switch to one of your saved camera views (the "Set View 1-5" keybindings) when you enter and/or leave combat, and when you mount and/or dismount, optionally leaving the camera alone in arenas, battlegrounds, delves (Retail only), dungeons and/or raids. Options: `/cim`

### Compass

A flight HUD that shows which way you're heading. A ring of compass points rotates around a fixed arrow as you turn, with your heading in degrees in the middle. Both styles are skinned like an aircraft heading indicator: a charcoal case with a brass bezel around the face (which takes the background's color), white tick marks, and amber main directions. It starts centered on the screen. Options: `/compass`

The Style option picks the look: Bars (the default), a horizontal strip of bars that slides sideways as you turn, showing 3 bars on either side of your heading, or Dial, a round face that turns as you do. With Dial picked, **As Minimap Overlay** draws its tick marks & letters around the edge of the minimap instead, with your heading in degrees below it (no case or face, and clicks still reach the map). With the game's Rotate Minimap setting on, the ring turns with the map; otherwise north stays at the top, and the minimap's arrow points at your heading on the ring. It follows the minimap's size and position, so the scale, background and position options don't apply to it. Next to it, a **Rotate Minimap** checkbox turns the game's minimap rotation on or off and keeps it across reloads (the game itself doesn't); it's left out when SexyMap is loaded, since SexyMap has its own. Use the options to change the scale and the background's color & opacity. Hold Shift and left-click drag to move it, and use `/compass reset` to re-center it. Bind a key to toggle it in Key Bindings (unassigned by default), or use `/compass toggle`, `/compass show` and `/compass hide`.

### Cooldown Bar Global

A customizable bar to visually track the global cooldown. Options: `/cbg`

Use `/cbg move` to toggle 'Move' mode, which keeps the bar visible so you can drag it into place.

> [!NOTE]
>
> This util is a resurrection of an add-on that I used many moons ago, originally created by **Radagast7**.
>
> If you have a link to the original (e.g. an old GitHub or CurseForge page), please post a message & share it, and I'll properly link to it here.

### Mobile Banking Timer

A countdown of how long your Mobile Banking guild chest has left. It appears as soon as the cast finishes, counts down the chest's 5 minutes, and hides the moment time runs out. A `/reload` or relog doesn't lose it. It's styled like SexyMap's clock, coords and zone text, and the options can change its font, size, outline and colors. Options: `/mbt`

Use `/mbt move` to keep it visible, then hold Shift and left-click drag it into place (`/mbt reset` puts it back). Mobile Banking has a 1 hour cooldown, so `/mbt test` runs the timer for 10 seconds to try it out.

### Obvious Statuses

Shows up to three statuses as a stack of rectangles, styled after Material UI's dark theme (pill-shaped, with round icons, on a rounded, shadowed panel), colored by state: the States tab's Colors pick one for Roaming and one for Fighting, one for Dragon and one for Steady, and one for Present and one for Past (all dark grey, #171717, to start). Above them, its Font and Size options set the text's font (the game's own, plus any your other addons share through LibSharedMedia) and size, Friz Quadrata TT at 22 to start. From bottom to top: combat ("Fighting" or "Roaming"), flight ("Dragon" when Skyriding is on, else "Steady"), and the zone's phase ("Past" or "Present", for zones where Zidormi can send you back in time). On WoW Forever, only the combat status is shown. Options: `/os`

Each status, and the range indicator, can be turned on or off with the Enable/Disable checkboxes at the top of the States tab (with the range indicator off, its tab can still be changed, but its settings have no effect). The flight and phase rectangles can each be hidden while you're in combat, and the phase one can optionally always show "Present" outside of Zidormi's zones. "Hide When Map Is Open" hides everything, the range indicator included, while the world map is open. Hold Shift and left-click drag to move it, or use the Positioning tab, which has a States section for the statuses and a Range section for the range indicator. With "Separate" on, each status gets its own frame that moves on its own (Reverse and Horizontal don't apply, and the Positioning tab has a dropdown to pick which status it moves).
It also has a range indicator: a separate square that shows whether your target is in range of a spell you name on the Range tab. An open eye under a green tint means it's in range, and a closed eye under a red tint means it's too far away. With no target (or one the spell can't be cast on), it shows the spell's icon, greyed out. If no spell by that name is found, it shows the red question mark. It's hidden while no spell is named. The Range tab also has a dropdown of sounds to play when your target comes into range, or when you select a target that's already in range (the game's own, plus any your other addons share through LibSharedMedia; click a row's speaker icon to preview it), sets its scale, can hide it while you're in combat, can draw a scope cross over it in a color and size you pick (with the cross on, the icon can be hidden, leaving only the cross, which then turns green in range and red out of range), and you can hold Shift and left-click drag it on its own.

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
