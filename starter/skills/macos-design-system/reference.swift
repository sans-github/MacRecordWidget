// Reference implementation, extracted verbatim from MacRecordWidget. Adapt, do not paste blindly:
// names like the recording medium and the zoom (panel size) choice are MacRecordWidget-specific.

import SwiftUI
import AppKit

// MARK: - Row palette

/// The semantic capsule colours, chosen 2026-09-24 (design option B) and
/// narrowed to two hues on 2026-09-28.
///
/// Hue says whether the app is *capturing*, not which subsystem a control
/// belongs to. Red is a recording in progress, audio or video alike; blue is
/// every other lit control in the row -- pin, mirror, the camera menu's
/// chevron well, quit. The camera green that mirror, S/M/L and the chevron
/// used to wear is gone: it read as a third, unexplained state sitting beside
/// the blue controls, and the subsystem it encoded is not something the user
/// has to act on. One consequence, unchanged: the user's own accent colour is
/// not honoured anywhere in the row.
///
/// Contrast, computed rather than eyeballed: white on #FF383C is 3.57:1 and
/// white on #007AFF is 4.02:1, both clearing the 3:1 that WCAG 1.4.11 asks of
/// a control's icon. That is a change from the green, which was a known,
/// accepted 1.88:1 failure. The one place still under 3:1 is the *bright point*
/// of the ember gradient (#FF7A3D, 2.59:1), which was already true of the audio
/// ember before this change and lasts a fraction of a second per sweep.
enum RowPalette {
    /// #FF383C. A live recording, audio or video. Sits between systemRed's
    /// light (#FF3B30) and dark (#FF453A) values, so one number covers both
    /// appearances.
    static let capture = Color(red: 1.0, green: 0.2196, blue: 0.2353)

    /// #007AFF. Every lit control that is not a recording: pin, mirror,
    /// the chevron well, quit. This is systemBlue's *light* value used in both
    /// appearances, so the dark panel gets a slightly heavier blue than macOS
    /// would pick.
    static let control = Color(red: 0.0, green: 0.4784, blue: 1.0)

    /// The glyph on any lit capsule. See the contrast note above.
    static let glyphOn = Color.white
}

// MARK: - Live Ember

/// The drifting gradient a capture control wears while it is actually
/// recording.
///
/// Two channels, both on a 3.4s period: the gradient's axis sweeps across the
/// capsule, and a coloured glow breathes just outside it. 3.4s is deliberately
/// not a near-match to `RecordingDot`'s 1.6s blink -- two indicators at almost
/// the same rhythm read as a rendering fault, while two at obviously different
/// rhythms read as two indicators.
///
/// One case, not two. The mic and the video button wear the *same* ember in the
/// same red: what the animation reports is "this app is recording you", and the
/// medium is already said by the glyph, the timer and which capsule is lit.
/// The two mediums are mutually exclusive, so two embers can never be on screen
/// at once to be told apart anyway.
enum EmberHue {
    case capture

    /// What the gradient collapses to when it cannot animate.
    var flat: Color { RowPalette.capture }

    /// Dark end, mid, bright end. The dark mode variant lifts the dark stop and
    /// warms the bright one, because the same gradient on a dark panel reads
    /// muddier than it does on a light one.
    func stops(dark: Bool) -> [Color] {
        if dark {
            return [Color(red: 0.5569, green: 0.1059, blue: 0.0706), // #8E1B12
                    RowPalette.capture,
                    Color(red: 1.0, green: 0.6235, blue: 0.2706)]    // #FF9F45
        } else {
            return [Color(red: 0.7216, green: 0.0824, blue: 0.0588), // #B8150F
                    RowPalette.capture,
                    Color(red: 1.0, green: 0.4784, blue: 0.2392)]    // #FF7A3D
        }
    }

    /// The breathing glow outside the capsule.
    var glow: Color { Color(red: 1.0, green: 0.3529, blue: 0.2353) }
}

/// The ember fill itself.
///
/// Driven by `TimelineView(.animation)` rather than a `repeatForever`
/// animation, for the same reason `RecordingTimer` is: there is no animation to
/// start, own or invalidate, so the phase cannot be left running after the
/// recording stops, and it recomputes correctly when the panel is reopened.
///
/// It falls back to the flat fill under two separate conditions, checked
/// independently: Reduce Motion (the same `accessibilityReduceMotion` that
/// `RecordingDot` already reads -- one mechanism, not two) and Increase
/// Contrast, where a moving gradient is exactly the wrong thing to draw.
struct EmberCapsule: View {
    let hue: EmberHue

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    /// Seconds for one full there-and-back sweep.
    private static let period: Double = 3.4

    var body: some View {
        if reduceMotion || contrast == .increased {
            Capsule().fill(hue.flat)
        } else {
            TimelineView(.animation) { context in
                let phase = Self.phase(at: context.date)
                let ramp = hue.stops(dark: colorScheme == .dark)
                // Symmetric five-stop ramp -- dark, hue, bright, hue, dark --
                // so the sweep has no visible seam where it turns around.
                let colors = [ramp[0], ramp[1], ramp[2], ramp[1], ramp[0]]
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: UnitPoint(x: -0.4 + 1.4 * phase, y: 0),
                            endPoint: UnitPoint(x: 0.6 + 1.4 * phase, y: 1)
                        )
                    )
                    // The glow is a shadow rather than a stroke, so it sits
                    // outside the capsule and never eats into the glyph's
                    // already-marginal contrast against the fill.
                    .shadow(
                        color: hue.glow.opacity(0.55 * phase),
                        radius: 4 + 3 * phase
                    )
            }
        }
    }

    /// 0 → 1 → 0 across one period, eased, so the sweep and the glow turn
    /// around smoothly instead of snapping back at the seam.
    private static func phase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return (1 - cos(2 * .pi * t)) / 2
    }
}

// MARK: - Capsule controls

/// The background every control in the row wears, in both states.
///
/// Off: the scale's corner radius, `controlBackgroundColor`, and the constant
/// 1pt `separatorColor` outline, which is what makes the resting row read as
/// one family of nine identical objects.
///
/// On: fully round, filled with the control's semantic hue, and *no* outline --
/// the fill is the edge. This is a real discontinuity: an on control changes
/// silhouette as well as colour. The one thing holding the row together across
/// it is that the height never changes, which is why `PanelScale.controlHeight`
/// is applied to every control rather than left to its content.
struct CapsuleControlBackground: View {
    let scale: PanelScale
    let isOn: Bool
    let tint: Color
    /// Non-nil only while this control is the live capture.
    let ember: EmberHue?

    var body: some View {
        if isOn {
            if let ember {
                EmberCapsule(hue: ember)
            } else {
                Capsule().fill(tint)
            }
        } else {
            RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }
}

/// The chrome shared by every button and toggle in the row.
///
/// A `View` rather than more code inside the `ButtonStyle`, because a
/// `ButtonStyle` cannot read the environment and the disabled dimming has to
/// come from `isEnabled` -- the native bordered style used to supply that for
/// free.
private struct CapsuleControlChrome<Label: View>: View {
    let scale: PanelScale
    let isOn: Bool
    let tint: Color
    let ember: EmberHue?
    let isPressed: Bool
    let label: Label

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label
            .foregroundStyle(isOn ? RowPalette.glyphOn : Color(nsColor: .labelColor))
            .padding(.horizontal, scale.controlPaddingH)
            .frame(height: scale.controlHeight)
            .background(
                CapsuleControlBackground(scale: scale, isOn: isOn, tint: tint, ember: ember)
            )
            // The background is a shape, so without this only the drawn pixels
            // would be clickable in the off state's rounded corners.
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.75 : 1)
            .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Used directly by the quit button, which has no off state, and indirectly by
/// every toggle through `CapsuleToggleStyle`.
struct CapsuleControlButtonStyle: ButtonStyle {
    let scale: PanelScale
    let tint: Color
    var ember: EmberHue? = nil
    /// The quit button passes `true`: it is a permanent capsule.
    var isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        CapsuleControlChrome(
            scale: scale,
            isOn: isOn,
            tint: tint,
            ember: ember,
            isPressed: configuration.isPressed,
            label: configuration.label
        )
    }
}

/// Replaces `.toggleStyle(.button)` on every toggle in the row.
///
/// The native bordered style cannot draw a fully round on state, and its
/// background geometry comes from the label's own symbol metrics rather than
/// from the glyph frame, which is what made the pin taller than its siblings.
/// Both problems go away once the background is an explicit shape on an
/// explicit height.
struct CapsuleToggleStyle: ToggleStyle {
    let scale: PanelScale
    let tint: Color
    var ember: EmberHue? = nil

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        // A custom style means a Button underneath, which does not carry the
        // toggle's own state to VoiceOver the way `.button` did. `.isSelected`
        // is the macOS-native way to say "this one is on" and needs no string,
        // so it cannot drift from the `.help` text the way a second label would.
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
        .buttonStyle(
            CapsuleControlButtonStyle(
                scale: scale,
                tint: tint,
                ember: ember,
                isOn: configuration.isOn
            )
        )
    }
}

// MARK: - RecordingDot

/// The blinking amber "recording" dot, shared by the menu bar icon and the
/// audio button so the two indicators cannot drift apart in colour or rhythm.
///
/// Mount it only while recording: the blink starts in `onAppear`, so its
/// lifetime *is* the recording state and there is no separate flag to keep in
/// sync. Under Reduce Motion it holds steady rather than disappearing, since it
/// is the indicator, not decoration.
@MainActor
struct RecordingDot: View {
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 1.0

    static let color = Color(red: 1.0, green: 0.620, blue: 0.200)

    var body: some View {
        Circle()
            .fill(Self.color)
            .frame(width: diameter, height: diameter)
            .opacity(reduceMotion ? 1.0 : opacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.15
                }
            }
            // The toggle already announces recording state; a second
            // announcement for the dot would just be noise.
            .accessibilityHidden(true)
    }
}


enum PanelScale: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge, full

    var id: String { rawValue }

    /// Spelled out for tooltips and VoiceOver.
    var helpLabel: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .full: "Full Width"
        }
    }

    var smaller: PanelScale? { step(-1) }
    var larger: PanelScale? { step(1) }

    private func step(_ offset: Int) -> PanelScale? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self) else { return nil }
        let j = i + offset
        return all.indices.contains(j) ? all[j] : nil
    }

    /// Large, extra large and full track the display rather than a hardcoded
    /// number: half, three quarters and all of the screen's width. Each is
    /// clamped to at least the medium width, because on a small display half
    /// the screen can be narrower than medium, which would put the sizes out of
    /// order.
    ///
    /// It is the *panel* that measures the fraction, not the preview inside
    /// it, so the screen margin comes off the top. Sizing the preview to half
    /// the screen instead makes the panel wider than half by exactly that much,
    /// and it laps over a window tiled to the left half.
    ///
    /// The preview is 16:9, so on a 16:9 display a full-width panel is taller
    /// than the screen. Every screen-relative width is therefore also capped at
    /// the widest preview whose panel (preview plus button row) fits the
    /// visible height. On a 16:10 MacBook full is the full width; on a 16:9
    /// monitor it stops a little short of it, and extra large may meet it.
    ///
    /// Every branch returns explicitly. One case here needs more than a single
    /// expression, which makes this a switch statement rather than a switch
    /// expression, and then the one-line cases are no longer implicit returns.
    /// Swift 5.9 (Xcode 15.2, which CI uses) rejects the mix.
    var previewWidth: CGFloat {
        switch self {
        // 400, not the 320 it started at. At 320 the sum of the fixed controls
        // left the camera picker about 6pt wide: present, but neither readable
        // nor clickable, so it went to 380 with the mirror toggle and to 400
        // when the play glyph joined the timer (2026-10-15). The picker is the
        // last thing to get space because it is the only flexible item, so a
        // new button silently comes out of its width.
        case .small: return 400
        case .medium: return 480
        case .large: return screenWidth(fraction: 0.5)
        case .extraLarge: return screenWidth(fraction: 0.75)
        case .full: return screenWidth(fraction: 1)
        }
    }

    private func screenWidth(fraction: CGFloat) -> CGFloat {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 960, height: 600)
        let wanted = (visible.width * fraction - PanelSizer.screenMargin).rounded(.down)
        let rowHeight = verticalPaddingTop + controlHeight + verticalPaddingBottom
        let fitsHeight = ((visible.height - rowHeight) * 16 / 9).rounded(.down)
        return max(480, min(wanted, fitsHeight))
    }

    /// 16:9, so the preview matches the aspect of the cameras feeding it.
    var previewHeight: CGFloat { (previewWidth * 9 / 16).rounded() }

    /// The layout box the symbol sits in. `glyphFont` is the symbol's own
    /// point size and the two track together at every scale (14/11 = 0.79,
    /// 16/13 = 0.81, 17/14 = 0.82), so moving one without the other leaves a
    /// symbol rattling in a box that no longer fits it.
    ///
    /// Large is 17, down from 20. At large the glyph box *is* the control's
    /// content -- the bordered style adds almost nothing on top -- so the glyph
    /// is the lever on the height of the whole bar. See `controlHeight`.
    var glyphSize: CGFloat {
        switch self {
        case .small: 14
        case .medium: 16
        case .large, .extraLarge, .full: 17
        }
    }

    var glyphFont: Font {
        switch self {
        case .small: .system(size: 11, weight: .regular)
        case .medium: .system(size: 13, weight: .regular)
        case .large, .extraLarge, .full: .system(size: 14, weight: .regular)
        }
    }

    /// Text in the button row: the camera name and the MM:SS timer.
    ///
    /// `ControlSize` alone does not carry text size, so every scale sets it.
    ///
    /// Large is 13pt, which is the macOS system default for a `.regular`
    /// control. It used to be 15, and the comment here used to argue for 15 on
    /// the grounds that 13 beside a 20pt glyph reads as too small. That
    /// argument was correct and is not being ignored -- it is being answered on
    /// the other side: the glyph came down to 17 in the same pass, so the
    /// box-to-text ratio is 17/13 = 1.31, near the 20/15 = 1.33 it replaces.
    /// Moving the font alone would have taken it to 1.54 and made the row
    /// worse, which is what the old comment was warning about.
    var controlFont: Font {
        switch self {
        case .small: .system(size: 10)
        case .medium: .system(size: 12)
        case .large, .extraLarge, .full: .system(size: 13)
        }
    }

    /// Only the camera menu reads this now. Every other control in the row is
    /// drawn by `CapsuleToggleStyle`, which takes its height from
    /// `controlHeight` rather than from the platform's control metrics.
    var controlSize: ControlSize {
        switch self {
        case .small: .mini
        case .medium: .small
        case .large, .extraLarge, .full: .regular
        }
    }

    /// Padding inside the timer's box, between the digits and its border. Its
    /// height comes from `controlHeight` like every other item in the row.
    var timerPaddingH: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large, .extraLarge, .full: 8
        }
    }

    /// Diameter of the blinking recording dot on the audio button.
    var recordingDotSize: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large, .extraLarge, .full: 7
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        // Six gaps at this scale, so each point here costs the picker six.
        case .small: 8
        case .medium: 14
        case .large, .extraLarge, .full: 18
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .medium: 12
        case .large, .extraLarge, .full: 16
        }
    }

    /// Top and bottom are separate numbers, and at large they differ.
    ///
    /// The two gaps are not the same kind of gap. The top gap sits between the
    /// row and the window's own edge, where there is nothing. The bottom gap
    /// sits between the row and the hard, dark, high-contrast top edge of the
    /// preview image, which visually pulls. Equal numbers therefore read
    /// bottom-heavy, so the bottom gets a point less than the top.
    ///
    /// Large is 7/6, down from 11/11. That takes the whole bar from roughly
    /// 43pt to roughly 32pt, about 1.14x the height of Photo Booth's title bar
    /// rather than 1.52x. Medium and small are unchanged in this pass: the
    /// large numbers are meant to be looked at on hardware before the other two
    /// follow, and small in particular has no width left to give.
    var verticalPaddingTop: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large, .extraLarge, .full: 7
        }
    }

    var verticalPaddingBottom: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large, .extraLarge, .full: 6
        }
    }

    /// The height every control in the row holds, in every state.
    ///
    /// Stated once here rather than left to each control's own content, and
    /// that is load-bearing twice over. The semantic capsules change silhouette
    /// between off and on, so a constant cap height is the only thing keeping
    /// the row on one horizontal baseline. And the pin used to render 6-7px
    /// taller than its eight siblings despite carrying an identical modifier
    /// chain, because the bordered button style sized its own background from
    /// the label's intrinsic symbol metrics rather than from the glyph frame.
    /// A background drawn against this number cannot do that.
    ///
    /// Large is 22pt, the HIG minimum for a control: nine of these are click
    /// targets and two of them start a recording, so the Photo Booth parity
    /// work stops at the floor rather than going under it. Medium and small
    /// hold the heights they render at today.
    var controlHeight: CGFloat {
        switch self {
        case .small: 17
        case .medium: 20
        case .large, .extraLarge, .full: 22
        }
    }

    /// Horizontal padding inside a control, either side of the glyph box.
    ///
    /// **One number for both states, and it must stay that way.** It used to be
    /// 6 when on and 4 when off, on the argument that the capsule's round ends
    /// need the extra 2pt to clear the glyph. The cost was that every control
    /// grew 4pt the moment it lit: starting a recording pushed the timer, the
    /// video button, the mirror, the camera menu, S/M/L and quit 4pt to the
    /// right, and pressing pin or mirror did the same to everything after them.
    /// A row that moves when you use it is worse than a capsule with tight
    /// ends, and the ends measure fine: at the large scale the cap's inner edge
    /// is 4.0pt in at the glyph box's top corner, which the glyph's own ink
    /// sits inside of.
    ///
    /// If this is ever raised, raise it for both states at once and check
    /// `previewWidth` first -- it comes out of the camera menu, which is the
    /// only flexible item in the row, and 2pt here is 32pt off the menu.
    var controlPaddingH: CGFloat { 4 }

    /// The green well the camera menu's chevron sits in.
    var chevronWellWidth: CGFloat {
        switch self {
        case .small: 11
        case .medium: 13
        case .large, .extraLarge, .full: 14
        }
    }

    var chevronFont: Font {
        switch self {
        case .small: .system(size: 7, weight: .semibold)
        case .medium: .system(size: 8, weight: .semibold)
        case .large, .extraLarge, .full: .system(size: 9, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: 4
        case .medium: 5
        case .large, .extraLarge, .full: 6
        }
    }

    var pickerMaxWidth: CGFloat {
        switch self {
        case .small: 110
        case .medium: 200
        case .large, .extraLarge, .full: 260
        }
    }
}
