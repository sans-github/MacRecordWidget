---
requirements:
  summary: The MacRecordWidget popover needs three targeted UI changes. First, the flickering recording-status dot above the Start button must be removed entirely and the Start/Stop buttons moved up to fill the vacated space. Second, the Start and Stop buttons must sit on a single horizontal row instead of being stacked vertically. Third, the Stop button's behavior changes: it stops only the audio recording (fires the Stop shortcut) without killing Photo Booth, so the user can immediately start a new recording session from Photo Booth without returning to the menu bar. The Quit button remains unchanged.
  key_points:
    - Remove the flickering dot indicator completely (no replacement).
    - Start and Stop buttons move to a single row, side by side, and shift up to fill the space freed by removing the dot.
    - Stop only fires the Stop shortcut; Photo Booth is left running.
    - Start behavior is unchanged.
    - Quit button is untouched.
  additional_context: none
  gathered_by: orchestrator-inline
---
