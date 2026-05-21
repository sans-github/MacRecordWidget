# PRD: Popover Button Layout

## Goals

Tighten the MacRecordWidget popover by removing a flickering UI element, consolidating the Start/Stop controls into a single row, and stopping recordings without closing Photo Booth so users can chain sessions immediately.

**Non-goals:** no changes to the Quit button, no changes to Start behavior, no replacement for the removed dot indicator.

**Success metric:** a user can stop a recording and start a new one from Photo Booth without touching the menu bar widget.

## Background

The current popover stacks Start and Stop buttons vertically with a recording-status dot above Start. The dot flickers and adds no actionable information. Photo Booth closes when Stop is pressed, which forces the user back to the menu bar to reopen it for a follow-up recording.

## Changes

### 1. Remove the recording-status dot

The flickering dot above the Start button is removed entirely. Nothing replaces it. The vertical space it occupied is reclaimed by shifting the button row up.

### 2. Horizontal button row

Start and Stop buttons move from a vertical stack to a single horizontal row, side by side. They shift up to fill the space freed by removing the dot. All other popover content (Quit button, Toggle) is untouched.

### 3. Stop behavior: leave Photo Booth running, keep popover open

`stopRecording()` currently fires the Stop shortcut only and does not close Photo Booth (Photo Booth is the Quit button's responsibility). The implementation must confirm this is already the case, or make it so.

The desired end state: pressing Stop fires the Stop shortcut, leaves Photo Booth open, and keeps the popover open so the user can immediately press Start again for a follow-up recording without reopening the widget.

## Scope

| Area | In scope |
|------|----------|
| UI | Remove dot, horizontal button row, shift up |
| RecordingManager | Confirm/fix `stopRecording()` does not close Photo Booth |
| Start behavior | No change |
| Quit button | No change |
| Video toggle | No change |

## Acceptance criteria

- The recording-status dot does not appear in the popover under any state.
- Start and Stop buttons are side by side on a single row.
- Pressing Stop fires the Stop shortcut, leaves Photo Booth running, and keeps the popover open.
- Pressing Start behaves identically to the pre-change behavior.
- The Quit button continues to close Photo Booth and quit the app.
