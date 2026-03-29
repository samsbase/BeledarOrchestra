Beledar Orchestra addon
=======================

Install:
1. Unzip the BeledarOrchestra folder into:
   World of Warcraft\_retail_\Interface\AddOns\
2. Restart WoW or /reload.
3. Enable the addon on the character select screen if needed.

What this build does:
- Leader/assist panel with a 5x5 measure grid.
- Traffic light that turns green when the current target's helpful auras match the selected measure.
- Bow button for the leader/assist.
- Raid members get a button showing their assigned emote based on their raid slot (1-40).
- Selected measure is synced across the raid via addon comms.

Important:
- The measure data is mostly placeholders for now.
- Unknown entries are stored as "PLACEHOLDER" and are ignored by the validator.
- The emote button is disabled when your slot is still a placeholder.
- Edit the MEASURES table near the top of BeledarOrchestra.lua to replace placeholders with the real sheet data.

Slash commands:
/bo               - toggle the main panel
/bo show          - show the main panel
/bo hide          - hide the main panel
/bo measure 7     - set the active measure to 7
/bo reset         - clear the active measure

How validation works:
- The addon scans helpful auras on your current target.
- It builds observed counts by spell ID.
- It compares those counts against the expected counts for the selected measure.
- PLACEHOLDER slots are ignored.
- Green = exact match.
- Red = mismatch.
- Yellow = no measure selected, wrong target, or no useful data.

Editing data:
- Each measure has 40 raid slots.
- Example:
  MEASURES[1][1] = "CHEER"
  MEASURES[1][2] = "SONG"
- Supported emote tokens in this build:
  CHEER, SONG, DANCE, MELANCHOLY, VIOLIN, APPLAUD, CONGRATS, ROAR, SING, BOW, PLACEHOLDER

Notes:
- Raid slot assignment is live based on WoW's raid roster order.
- If the raid order changes, assignments change too.
- Bow still requires a real button click.
