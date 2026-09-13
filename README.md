# Loupe

A personal screenshot utility for macOS: region/window/full-screen/scrolling capture,
an annotation editor, a native color picker, select-to-copy OCR, and pin-to-screen — all native
Swift/AppKit/SwiftUI, no third-party dependencies, no App Sandbox.

## First run (from the DMG — no Xcode needed)

1. Open `Loupe.dmg`, drag **Loupe.app** into your **Applications** folder (or anywhere you like).
2. **First launch only**: macOS will refuse to open it normally because it's signed for local use
   only, not notarized by Apple. Do one of:
   - Right-click (or Control-click) **Loupe.app** → **Open** → confirm in the dialog that appears, or
   - If that dialog doesn't offer an "Open" option, go to **System Settings → Privacy & Security**,
     scroll down, and click **Open Anyway** next to the mention of Loupe — then confirm once more.
   - You only need to do this once per build of the app.
3. On your first capture attempt, macOS will need **Screen Recording** permission. Loupe detects
   this automatically and shows a dialog with an **Open System Settings** button — grant access
   under *Privacy & Security → Screen Recording*, then quit and relaunch Loupe (macOS requires a
   relaunch after granting this permission).
4. Loupe lives in the menu bar only (no Dock icon) — look for the viewfinder icon.

To rebuild the app/DMG yourself after any changes (no Xcode required, just the Command Line Tools
already on this Mac):

```bash
cd /Users/julienbarezi/Documents/Code/loupe
./build.sh                                                  # produces build/Loupe.app
hdiutil create -volname Loupe -srcfolder build/Loupe.app -ov -format UDZO build/Loupe.dmg
```

## First run (from Xcode instead, if you ever install it)

1. Open `Loupe.xcodeproj` in Xcode, select the **Loupe** scheme, and hit **⌘R**.
2. Same Screen Recording permission step as above applies.

## Default shortcuts (all rebindable in Preferences)

| Action              | Shortcut |
|---------------------|----------|
| Capture Region      | ⌃⇧2      |
| Capture Window      | ⌃⇧3      |
| Capture Full Screen | ⌃⇧4      |
| Scrolling Capture   | ⌃⇧5      |
| Color Picker        | ⌃⇧C      |

These were chosen so they don't collide with macOS's own ⌘⇧3/4/5 screenshot shortcuts. Change any
of them from the menu bar icon → Preferences → Keyboard Shortcuts (click the field, then press the
new combo).

## What each capture mode does

- **Region**: freezes the screen, lets you drag a rectangle (dimension HUD + pixel loupe follow the
  cursor), then opens the result in the annotation editor.
- **Window**: hover to highlight a window, click to capture just that window.
- **Full Screen**: captures the main display immediately.
- **Scrolling Capture**: drag a region like normal, then a small "Stop & Stitch" HUD appears —
  scroll the target content yourself and Loupe grabs a frame every ~0.6s, aligning and stitching
  them into one tall image when you click Stop.
- **Color Picker**: opens the system eyedropper (`NSColorSampler`); the picked color's hex is
  copied to the clipboard and shown briefly in a small HUD. Recent colors are listed in the menu
  bar dropdown for one-click copy.

In the annotation editor: Select, Arrow, Rectangle, Ellipse, Line, Text, Highlight, Blur, and Crop
tools, plus Undo/Redo, and a bottom bar for Copy, Save, Pin (floating always-on-top window), and
Copy Text (OCR over the whole image).

## Known rough edges to expect on first real run

I couldn't build or launch this myself (Xcode wasn't installed on this machine), so a few
pixel-geometry details are my best-informed implementation but are the most likely things to need
a one-line fix once you actually run it:

- **Region/scrolling capture coordinates**: I convert the on-screen drag rectangle from AppKit's
  bottom-left-origin coordinates to the top-left-origin rect `SCStreamConfiguration.sourceRect`
  expects (see `Core/ScreenCoordinates.swift`). If a region capture comes out vertically shifted or
  mirrored, this is the one place to flip.
- **Crop/blur tools**: convert on-screen annotation coordinates to the underlying image's pixel
  coordinates: if a crop or blur lands in the wrong place, check the scale/origin math in
  `AnnotationCanvasView.swift` (`renderedImage()` and `drawBlur`).
- **Scrolling capture stitching**: `Core/ScrollStitcher.swift` aligns frames by comparing grayscale
  row signatures; it works well for most scrollable content but can misalign on very repetitive
  content (long lists of identical rows) — if so, the frame capture interval in
  `ScrollingCaptureSession` (currently 0.6s) is the first thing to tune.

None of these should require more than a small, targeted fix — tell me what you see when you try
each capture mode and I'll iterate quickly.

## Project layout

```
Loupe/
  App/AppDelegate.swift          Menu-bar-only entry point, wires everything up at launch
  Core/                          Capture pipeline, hotkeys, preferences, history, OCR, color picker
  UI/Overlay/                    Region-selection and window-picker full-screen overlays
  UI/Annotation/                 The post-capture editor (canvas + toolbar + window)
  UI/Pin/                        Floating "pinned" screenshot windows
  UI/ColorPicker/                Color-pick confirmation HUD
  UI/MenuBar/                    Status bar menu
  UI/Preferences/                Preferences window, including the shortcut recorder
  UI/DesignSystem/Theme.swift    The MUJI-style palette/tokens used everywhere
```
