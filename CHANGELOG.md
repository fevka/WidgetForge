# Widget Forge - Changelog

## v1.1.1 (2026-02-19)

### ✨ Settings Migration & Polish
-   **Retirement Home Widget**:
    -   Settings moved to the unified **Slide-In Panel** for a consistent experience.
    -   **New Visibility Options**: Added "Combat Only" and "Instance Only" behaviors.
    -   **Refined Layout**: Shape, Color, Size, and Offsets are now logically grouped and aligned.
    -   **Cleanup**: Removed redundant "Dot" shape and renamed "Square (Border)" to "Square".
-   **Cursor Ring Widget**:
    -   Migrated to Slide-In Panel with **Real-time Preview** support.
    -   Fixed transparency and visibility logic to prevent conflicts.

### 🐛 Bug Fixes
-   **Dropdown Menus**: Fixed an alignment issue where dropdown lists would not match the button width. They now expand correctly to fit the container.
-   **Combat Logic**: updated visual combat detection to use `UnitAffectingCombat` for better reliability.
-   **Slider Precision**: Sliders now correctly display small decimal values (e.g., 0.005) instead of rounding to zero.



### ✨ Dragonriding Widget Overhaul
- **Dedicated UI**: Completely redesigned the Dragonriding Settings window with a wider, 2-column layout for easier configuration.
- **Independent Borders**: You can now set distinct Border Sizes and Colors for the Vigor Bar and Speed Bar, independent of the global bar settings.
- **Isolaton Mode**: Dragonriding bars now automatically lock their layout controls to prevent conflicts. The Dragonriding button acts as a smart toggle to unlock/remove the widget.
- **Background Box**: Added a customizable background box behind the widget with adjustable padding (X/Y) and color.
- **Speed Bar Improvements**: Added `Empty Color` setting for the unfilled portion of the speed bar and fixed visual overlap with borders.

### 🚀 UI & UX Improvements
- **Accordion Selection**: New collapsible element categories (System, Stats, Utils) for a cleaner selection experience.
- **Smart Toggles**: Clicking an already active element button now correctly removes it. active buttons are clearly highlighted in Blue.
- **Refined Layout**: Widened the main configuration window to **870px** for better spacing.
- **Standardization**: All separators and borders now use a consistent visual style (Dark 1px Line).

### 🐛 Bug Fixes
- **Layout**: Fixed issues where global border settings would confusingly persist on detailed widgets.
- **Ghost Text**: Fixed blurry "ghost" text issues in dropdown menus.

## v1.0.2 (2026-02-12)

### ✨ New Features
- **Divider Element**: New element type added to separate stats. Supports both **Graphic Line** and **Text Character** modes with custom color and orientation settings.
- **Auto-Resizing Bars**: Bar backgrounds now automatically expand or shrink to fit their content (elements + spacing), keeping the drag handle perfectly at the edge.
- **Negative Spacing**: The spacing slider now allows values down to **-10**, giving you total control over widget density.

### 🐛 Bug Fixes & Optimization
- **Layout Jitter Fix**: Implemented "Stable Digit Width" logic. Widgets now calculate their size based on a fixed template, preventing the "bouncing" effect when numbers change (e.g., from 9 to 10).
- **Proportional Padding**: Added automatic 1-digit safety padding to every element to ensure consistent spacing regardless of value length.
- **Word Wrap Prevention**: Disabled automatic word wrapping for fixed-width widgets to maintain a single-line layout during rapid value changes.


## v1.0.1 (2026-02-11)

### 🐛 Bug Fixes
- **Stamina/Intellect stat index fix**: Stamina and Intellect were mapped to wrong API indices (3=Stamina, 4=Intellect). Stamina now displays the correct effective value.
- **tVal nil crash fix**: Fixed `attempt to index local 'tVal' (a nil value)` error that occurred when bar elements were modified while the update loop was running.
- **Speed stat correction**: "Speed" now correctly shows the Tertiary Speed stat from the character panel instead of movement speed.
- **Timer drift fix**: Update loop timer reset changed from subtraction to zero-reset to prevent frame buildup.
- **Gear stat refresh**: Character stats (Leech, Speed, etc.) now update immediately when equipment changes.

### ✨ New Features
- **Run Speed**: New stat type showing real-time movement speed percentage (updates dynamically while moving/mounted).
- **Armor**: New stat type displaying effective armor value.
- **Max HP**: New stat type showing maximum health points.
- **Number formatting**: Primary stats (Str, Agi, Sta, Int, Armor, Max HP) now display with comma separation (e.g., "7,034").

### 📝 Notes
- Removed deprecated `GetItemStats` API usage (removed in WoW 12.0).
- Debug commands (`/wfd`) used during development have been cleaned up.
