# Using MacRecordWidget

Click the menu bar icon to open the panel. The controls run left to right:

| Control | What it does |
|---|---|
| **Pin toggle** (pin icon) | Off, the panel closes when you click another app. On, it stays open. The setting persists across launches. |
| **Audio toggle** (microphone) | Starts and stops the audio recording. One button in two states: plain when idle, filled red with a blinking amber dot while recording. |
| **Timer** (MM:SS) | Counts up once recording is actually live, not from the click — see below. Counts up while recording. Shows `00:00` at launch, and keeps the last recording's duration on screen after you stop, until you start the next one. |
| **Video toggle** (video icon) | Starts and stops a video recording, saved into Photo Booth's library. Same two states as the audio button, and the same timer. Audio and video are mutually exclusive: while one is running the other is disabled. |
| **Mirror toggle** (flip icon) | Flips the preview left to right. On by default, and the setting persists across launches. It affects the preview only: recordings are always saved unmirrored, so text you hold up to the camera reads correctly in the file. Free to flip at any time, recording or not. |
| **Camera picker** | Chooses which camera feeds the preview and the video recording. Disabled while a video recording is running, since switching would truncate the file. |
| **Size buttons** (S / M / L) | Scale the entire panel: controls, spacing and preview. At L the panel is half your screen wide, so it sits alongside a window tiled to the other half. The choice persists across launches. |
| **Power button** | Stops any recording in progress, then quits. |

The panel stays open after you start or stop a recording, so you can press stop
without reopening it. Clicking the menu bar icon closes it either way, pinned or
not.

The first recording will prompt you to allow the app to run Shortcuts.

### Wait for the red button before you speak

Recording does not begin the instant you click. The click fires a Shortcut,
Shortcuts wakes, Voice Memos launches and arms the microphone — measured at
about a second, and more if Voice Memos was not already warm. Anything said in
that window is not captured, which is why first words used to go missing.

So the button stays dimmed and unclickable for a moment after you press it. When
it turns red, with the blinking dot and the timer running, the microphone is
live. That is your cue.

The wait is a fixed delay, not a detection: macOS gives no signal for "recording
has started", so the app cannot know for certain. It is tuned from measurement
with some margin.

### A caveat about the Shortcuts

The app fires a `shortcuts://` URL and macOS reports success as long as
something claims that URL scheme, which the Shortcuts app always does. It cannot
tell whether your `Start` shortcut actually exists or ran. If the shortcut is
missing or broken, the app will still show itself as recording. Check Voice
Memos if you are unsure.

