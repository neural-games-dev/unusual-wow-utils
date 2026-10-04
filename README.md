# Unusual WoW Utils

This add-on is a collection of utils to improve your WoW playing experience.

By default, all of the utils are enabled, but you can disable specific utils using the settings window.

## Included Utils

### Auto Dungeon Queue

Quickly enter dungeon queues at the press of a keybind or with a slash command.

- `/adq` queues you for a random dungeon with your saved roles, without opening any windows. If you have no saved roles yet, it opens the Dungeon Finder so you can pick them.
- `/adq save <tank|healer|DPS>` saves your role(s), e.g. `/adq save tank DPS`. It also ticks the matching boxes in the Dungeon Finder. Roles your class can't fill are rejected.
- `/adq save` saves whichever roles are currently ticked in the Dungeon Finder.
- `/adq roles` shows your saved roles.
- `/adq help` lists the commands.

### Chat Tab Cycler

Just like your web browser, cycle through your chat tabs going forward AND backward, genius!

Yes, there is a default keybind to go to the next tab, BUT... it only goes forward!

This util allows you to go whichever direction your heart desires, PLUS, it has better highlighting of which tab is actually active!

### Combat Interface Manager

Hides UI elements (chat, minimap, quest tracker) when you enter combat and restores them when you leave. Options: `/cim`

### Cooldown Bar Global

A customizable bar to visually track the global cooldown. Options: `/cbg`

### Quest Log Counter

A counter showing how many quests you have in your log. It's locked in place by default; hold Shift and left-click drag to move it.

## Enabling & Disabling Utils

Open the settings with `/uwu` (or find "Unusual WoW Utils" under Options > AddOns) and toggle each util. Changes take effect after a `/reload`.

Combat Interface Manager, Cooldown Bar Global, and Quest Log Counter were previously standalone add-ons. If a standalone copy is still loaded, the matching util here is skipped so they don't clash. Disable the standalone add-on to use the bundled one.
