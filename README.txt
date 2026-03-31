Beledar Orchestra
================

**Beledar Orchestra** is a specialized coordination tool for World of Warcraft raids tackling the Hallowfall flame puzzle. It helps 40 players synchronize their emotes to successfully complete the event.

Overview
--------
The Divine Flame of Beledar in Hallowfall requires precise coordination from a full 40-man raid. This addon assigns one of 40 specific roles to every raid member, tracks their readiness, and validates the results in real-time.

Key Features
------------
- **Automatic Assignments**: Instantly gives every raid member a specific emote based on their position in the raid roster.
- **Live Synchronization**: Leader selections and player progress are synced across the entire raid automatically.
- **Validation System**: A "Traffic Light" indicator tells the leader exactly when the raid has performed the correct combination of emotes on the target.
- **Raid Overview**: Leaders can see a full grid of the raid, highlighting who is ready, who is offline, and who has completed their task.
- **Countdown Integration**: Built-in timers ensure everyone acts at the exact same moment.
- **Version Check**: Easily verify that everyone in the raid has the addon installed and up to date.
- **Multi-Language Support**: Works on all WoW client languages.

How It Works
------------

### As a Raid Participant
- **Stay Informed**: The **Beledar Assignment** window shows your assigned emote and raid slot.
- **Follow the Lead**: When the leader initiates a countdown, your window will update.
- **Action**: Once the timer hits zero, perform your emote. If you have the "Dance" assignment, the addon will help you track when to start and stop moving.
- **Leader Overrides**: If the leader manually changes your assignment, your UI will update immediately to reflect the change.

### As a Leader or Assistant
- **The Conductor Panel**: This is your command center. Open it by targeting the Divine Flame or typing `/conductor`.
- **Choose a Measure**: Select from 25 pre-set emote combinations (measures).
- **Coordinate**: Use the **Start** button to trigger a 10-second countdown for all addon users in the raid.
- **Monitor**: Watch the assignments grid to see players turn green as they complete their emotes.
- **Manual Overrides**: Click any player in the grid to manually change their assigned emote if needed.
- **Save/Load/Export**: Save custom assignment sets for specific measures or export them as a string to share with other leaders.
- **Validation**: Target the Divine Flame to see the status light. It turns **Green** when the current emotes on the flame match your selected measure.

Slash Commands
--------------
- `/conductor` — Toggle the main Conductor panel.
- `/conductor show` / `/conductor hide` — Show or hide the assignment window.
- `/conductor measure [number]` — Set the active measure (Leader only).
- `/conductor reset` — Clear the current active measure.

Installation
------------
1. Download and extract the `BeledarOrchestra` folder.
2. Place it in your `World of Warcraft\_retail_\Interface\AddOns\` directory.
3. Ensure the addon is enabled in your character select screen.

Important Notes
---------------
- **Raid Order**: Assignments are based on the current raid roster order. If the leader rearranges groups, assignments may shift.
- **Addon Requirements**: While the leader needs the addon to coordinate, raid members also need it installed to see their assignments and participate in the automated countdowns.
- **Automatic Show/Hide**: The interface is designed to automatically appear when you are in Hallowfall and disappear when you leave or enter combat.
