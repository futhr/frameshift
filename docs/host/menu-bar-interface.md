# Menu-Bar Interface

**Status:** interaction specification

**Reference:** the selected white perspective-frame mark on a navy field.
[FrameshiftMark.svg](../../host/macos/App/Icons/FrameshiftMark.svg) is its
canonical vector source.

## Product posture

Frameshift is a quiet menu-bar utility, not a dashboard. The primary flow is:

```text
open -> choose frame -> describe or choose image -> generate/render -> send
```

The macOS app has a Dock presence. Opening it from the Dock presents the same
authoritative artwork and frame controls as the menu-bar entry. The navy and
white mark appears in the Dock and its unboxed silhouette appears in the menu
bar.

Advanced provider, model, storage, pairing, and hardware details live in
Settings. The popover shows only information needed to choose artwork and know
whether it reached the selected frame.

## Menu-bar item

- Use the supplied mark's silhouette as a monochrome template at 18 points
  with 1×, 2×, and 3× representations. Test its optical weight at 16, 18, and
  20 points; keep the menu-bar rendering unboxed.
- Accessibility label: “Frameshift.”
- Primary click toggles the window-style popover.
- No animated menu-bar icon. Busy state uses a subtle static badge/dot or text
  inside the popover.

SwiftUI's `MenuBarExtra` with `.window` style is the implementation baseline.
Apple explicitly positions window style for richer popover-like content:
[MenuBarExtra documentation](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra).

## Popover layout

Target a compact width in the 360–420 point range and let content scroll before
growing into a large editor.

```text
┌──────────────────────────────────────┐
│ Paper — Hallway               status │
│                                      │
│ What should this frame show?         │
│ ┌──────────────────────────────────┐ │
│ │ instructions…                    │ │
│ └──────────────────────────────────┘ │
│ [＋ Image]  [⌕ Library]   [Generate] │
│                                      │
│ Search: forest, blue, pinned…        │  conditional
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│ │ preview │ │ preview │ │ preview │ │
│ │ ↻  pin ×│ │ ↻  pin ×│ │ ↻  pin ×│ │
│ └─────────┘ └─────────┘ └─────────┘ │
│                                      │
│ Waiting for next contact · 18:00     │
│ Settings…                       Quit │
└──────────────────────────────────────┘
```

The drawing is structural, not a visual-style prescription.

### Target row

The first row selects a paired frame or an explicitly configured offline render
profile. It shows one concise state: displayed, sending, refreshing, waiting
for contact, needs attention, or unpaired. Sleeping frames show the next
expected contact rather than an alarm-colored offline state.

### Instruction editor

One native multiline text editor accepts the user's generation/edit
instruction, including Return-delimited paragraphs. It has a visible
placeholder when empty, a bounded height with internal scrolling, and an
accessible label. Saving preserves embedded newlines. The selected display
profile contributes a versioned base instruction. A small
“Paper recipe,” “Photo recipe,” or “Pixel recipe” disclosure opens the full
effective instruction and allows advanced override; it does not clutter the
default flow.

When the selected item is an imported image, the field steers an edit or target
interpretation. When empty, it creates a new generated master. Provider absence
never blocks normal image import/render.

### Image source and search

- **Image** opens file/photo selection and accepts drag/drop or paste.
- **Library** reveals a single search field and recent/pinned results.
- Search matches titles, user labels, local Vision labels, selected frame,
  source/provider, and pinned state.
- A “similar” action may use local Vision feature prints; the UI identifies
  similarity results rather than pretending they are text matches.

Auto-labeling runs in the background and does not interrupt import. Generated
or machine labels remain editable in the full library/settings view.

### Result strip/grid

Each card is one immutable master or generated variant with a target preview.
The card exposes exactly three compact actions:

| Symbol | Action | Behavior |
| --- | --- | --- |
| `arrow.clockwise` | Regenerate | Creates a new sibling/child variant; preserves this result |
| `bookmark` / `bookmark.fill` | Pin | Protects the item and makes it easy to retrieve |
| `trash` or `xmark` | Remove | Removes from the active library and moves unreferenced data to recoverable trash |

Actions appear on hover/focus but pinned state remains visible. Every symbol
has a tooltip, accessibility label, keyboard focus, and command equivalent.
Remove does not immediately destroy a displayed or frame-referenced artifact.

Selecting a card previews it for the current frame. The primary button becomes
“Send,” “Queue for next contact,” or “Displayed” according to frame state.

## Slideshow editing

The compact UI may add selected stills to a playlist, reorder them, and set a
dwell. It never exposes transition effects because there are none. A frame's
minimum dwell is enforced. More complex schedule editing belongs in a separate
window opened from Settings/Manage Frames.

## Progress and failure

Use one line of plain status:

- “Generating locally…”
- “Rendering 192×128 Pixel artifact…”
- “Queued for Paper frame · next contact around 18:00”
- “Refreshing Paper frame · about 19 seconds”
- “Displayed”

Cancellation is offered while the operation can still be cancelled. Provider
refusal, authentication, quota, render, transfer, and display failures are kept
distinct and offer one relevant recovery action. The app never silently changes
AI provider or cloud destination.

## Settings boundary

Settings contains:

- frames, commissioning, pairing, names, and certificates;
- local/cloud provider order, models, licenses, quotas, and privacy policy;
- model/storage downloads and cache/trash retention;
- background launch and outbox availability;
- renderer defaults and full base instructions;
- accessibility and notification preferences;
- diagnostics/export with automatic secret redaction.

## Accessibility and keyboard behavior

- All icon-only actions have labels and Help tags.
- Full keyboard traversal follows visual order.
- Return runs the current primary action; Command-Return generates when the
  instruction field is focused; Escape closes transient search/popover state.
- Do not rely on color alone for status or pinned state.
- Respect reduced motion; the product has no content motion and needs no
  decorative popover animation beyond system behavior.
- VoiceOver reads result provenance and state without reading the entire prompt
  or digest unless the user opens details.

## Acceptance scenarios

1. Import a local image and queue it to a sleeping Paper frame without setting
   up an AI provider.
2. Generate locally, regenerate one variant, pin the preferred result, and
   remove the rejected variant without losing either unintentionally.
3. Search an auto-labeled library and distinguish literal from similar results.
4. Queue one still for each configured frame class without exposing
   video/animation controls.
5. Complete every action with keyboard and VoiceOver.
6. Understand whether bytes are queued, transferred, refreshing, or physically
   displayed from the compact status alone.
