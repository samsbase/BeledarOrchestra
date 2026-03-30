Beledar Orchestra v0.4.15
========================

A World of Warcraft addon for coordinating the Hallowfall Beledar flame
puzzle event with a full raid of 40 players.

Install
-------
1. Unzip the BeledarOrchestra folder into:
   World of Warcraft\_retail_\Interface\AddOns\
2. Restart WoW or /reload.
3. Enable the addon on the character select screen if needed.

Features
--------
General:
- Addon only loads/shows when in Hallowfall (Zone ID 2215) and not in combat.
- Auto-show/hide panels when entering/leaving the zone.
- Leader UI opens automatically for leaders/assists when targeting the Divine
  Flame of Beledar.
- Robust private aura handling using HasAnySecretValues and pcall.

Leader / Assist Panel ("Beledar Orchestra Conductor"):
- 5x5 measure selection grid (25 measures, 40 raid slots each).
- Traffic-light indicator: green when auras match, red on mismatch, yellow
  when no measure is selected or the target is wrong.
- "Start" button initiates a countdown (default 10s, configurable) before
  player emote buttons activate.
- "Countdown 5s" button for a quick 5-second countdown.
- "Retry" button resets the measure state and cancels any active in-game
  countdowns (/cd 0).
- "Lock in (Bow)" button for the leader/assist (glows when all auras match).

Assignment Management:
- Assigned Emotes grid (8 columns x 5 rows, matching WoW raid frames)
  showing each player's emote icon, name, and raid slot number.
- Manually overridden assignments highlighted with a thick gold border
  and tinted background.
- Player names turn red if offline or missing the required aura
  (Spell ID 1266536), and green when they perform their emote.
- Click any slot to change a player's emote via a dropdown menu.
- Save / Load / Clear Manual Assigns buttons (per-measure named sets).
- Export / Import all saved sets across all measures as a compact string.
- Delete saved sets from the Load menu.

Version Checking:
- "Check Versions" button (inside the Versions panel) pings all raid
  members and displays a color-coded grid:
  green = current version, yellow = outdated, red = missing addon.
- Toggle between Assignments and Versions views.

Player Panel ("Beledar Assignment"):
- Shows the player's raid slot, current measure, and assigned emote.
- Displays the addon version in the top-left corner.
- Emote button stays disabled and shows "(waiting)" until the leader
  presses Start and the countdown completes.
- After pressing Dance, the button changes to "Move!" then "Stop Moving!"
  tracking PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING events.
- Displays "(Modified by leader)" when the assignment has been manually
  overridden.
- After performing the emote, all buttons grey out until the leader
  selects a new measure or presses Retry.

Data Sync:
- Automatic lightweight measure-data sync (BO_DATASYNC protocol).
  Newer clients broadcast the full 25x40 measures table to older clients
  in the raid, keeping everyone up to date without manual intervention.

Communication:
- All coordination uses addon messages on the RAID channel:
  measure selection, overrides, start/retry, ping/pong, performed emotes,
  dance state, clear overrides, and data sync chunks.

Locale-Independent:
- Target identification uses NPC ID 255888 instead of the English name,
  so the addon works in all WoW client languages.

Slash Commands
--------------
/conductor             - toggle the main panel
/conductor show        - show the main panel
/conductor hide        - hide the main panel
/conductor measure 7   - set the active measure to 7 (leader only)
/conductor reset       - clear the active measure

How Validation Works
--------------------
- The addon scans helpful auras on your current target (NPC ID 255888).
- It builds observed counts by spell ID.
- It compares those counts against the expected counts for the selected
  measure.
- PLACEHOLDER slots are ignored.
- Green = exact match, Red = mismatch, Yellow = waiting / wrong target.

Supported Emotes
----------------
APPLAUD, BOW, CHEER, CONGRATS, DANCE, ROAR, SING, VIOLIN
(PLACEHOLDER is used for unassigned slots and is ignored by validation.)

File Structure
--------------
Measures.lua       - 25x40 emote assignment table
Core.lua           - constants, shared state, utility functions
Data.lua           - emote definitions, encoding helpers, data access
Comm.lua           - addon message handling (send/receive)
UI\PlayerUI.lua    - player assignment frame
UI\LeaderUI.lua    - leader/assist UI, grids, dialogs
DataSync.lua       - automatic measure-data synchronisation
Init.lua           - event handlers, slash commands, OnUpdate loop

Notes
-----
- Raid slot assignment is live based on WoW's raid roster order.
  If the raid order changes, assignments change too.
- Saved assignment sets are stored per-character in BeledarOrchestraDB.
- The addon requires the leader/assist to have the addon installed to
  coordinate measures. Raid members need the addon to see their
  assignments and perform emotes.
