---
requirements:
  summary: >
    MacRecordWidget is a lean menu-bar app that triggers Apple Shortcuts-based recording sessions
    from a two-button popover. This feature brings both the UI and the Swift codebase up to a
    shippable standard: the macOS Designer audits and rewrites the popover UI against HIG guidelines,
    and the Swift Engineer refactors the source to idiomatic, maintainable Swift.
  key_points:
    - "UI/HIG compliance: proper semantic colors, standard macOS control sizing, correct typography,
      and appropriate button styles (destructive tint for Stop, controlAccentColor for Start)."
    - "Swift modernization: migrate from ObservableObject/@StateObject to @Observable/@State,
      structured concurrency for background work, and typed error propagation."
    - "Reliability: guard against double-tap/rapid toggling, handle Accessibility permission denial
      in the osascript path, and remove optimistic state divergence."
    - "Popover dismissal cleanup: replace the 100ms async hack with a documented, consistent
      production-grade approach."
    - "No new features. Scope is strictly a polish and code-quality pass."
  additional_context: none
  gathered_by: orchestrator-inline
---
