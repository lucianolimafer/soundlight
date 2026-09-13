<div align="center">

# SoundLight

### iPhone-inspired volume and brightness HUDs for macOS

SoundLight replaces ordinary system feedback with fluid vertical controls that slide in from the edges of your screen. Brightness stays on the left. Volume stays on the right.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0D96F6)

</div>

## Demo

<!--
Add the product video here. GitHub renders uploaded MP4 files when their
user-attachments URL is placed on its own line.

Example:
https://github.com/user-attachments/assets/REPLACE_WITH_VIDEO_ID
-->

> **Demo video coming soon.**

---

## Download

Download the latest macOS disk image from [GitHub Releases](https://github.com/lucianolimafer/soundlight/releases/latest).

Release builds currently use ad hoc code signing. Developer ID signing and Apple notarization are planned before the stable release.

## What is SoundLight?

SoundLight is a lightweight macOS menu bar utility that monitors the system output volume and the built-in display brightness. When either value changes, a compact HUD appears at the corresponding edge of the screen, reflects the real system value, and then moves out of view.

The interface is intentionally minimal. There is no persistent window, no account, and no background service beyond the running menu bar app.

## Features

| Feature | Description |
| --- | --- |
| Independent HUDs | Brightness and volume use separate windows, so rapid input never moves one control across the screen or changes its identity. |
| Edge placement | Brightness enters from the left edge; volume enters from the right edge. |
| Fluid motion | Each HUD slides in, scales from 50% to full size, and reverses the animation when dismissed. |
| Smooth level changes | The fill level animates between system values instead of jumping between steps. |
| Real system values | Volume, mute state, and built-in display brightness stay synchronized with macOS. |
| Stress-safe transitions | Repeated or alternating key presses extend the correct HUD without restarting unrelated animations. |
| Adaptive appearance | Symbols, contrast, and materials respond to the current macOS light or dark appearance. |
| Menu bar controls | Volume and brightness can also be adjusted from the SoundLight menu bar panel. |
| Accessibility | Controls expose labels, values, and adjustable actions to macOS accessibility features. |

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later
- A Mac with a built-in display for brightness control

## Run SoundLight

1. Open `Package.swift` in Xcode.
2. Select the **SoundLight** scheme.
3. Choose **My Mac** as the run destination.
4. Press **Command–R** or click **Run**.
5. Use the volume or brightness keys to display the corresponding HUD.

SoundLight is a macOS app and uses AppKit. Selecting an iPhone or iPad as the run destination causes the build to fail because those platforms don't provide AppKit.

## How it works

1. `SystemControls` samples system audio and display state and publishes normalized values.
2. A control change is routed to either the brightness HUD or the volume HUD.
3. Each `HUDWindowController` owns an independent, nonactivating panel fixed to one side of the active screen.
4. SwiftUI animates the pill scale and fill level while AppKit animates the panel across the screen edge.
5. Repeated changes keep the relevant HUD visible; inactivity starts its exit animation.

## Menu bar panel

Click the SoundLight icon in the menu bar to open both vertical controls. Drag anywhere inside a pill to adjust its value. Select **Exit** to stop the app.

## Limitations

> [!IMPORTANT]
> Brightness integration relies on private macOS display services because Apple doesn't provide a public API for changing built-in display brightness. These interfaces may change in future macOS releases and may not be suitable for Mac App Store distribution.

- Brightness control targets the built-in display.
- External monitors may require DDC support and are not currently controlled by SoundLight.
- Some digital, aggregate, or external audio devices may not expose a writable master volume.
- SoundLight must remain running for the HUDs to appear.

## Project structure

```text
SoundLight/
├── .github/workflows/release.yml
├── CHANGELOG.md
├── Package.swift
├── README.md
├── Resources/Info.plist
├── scripts/package-release.sh
└── Sources/
    └── SoundLight/
        ├── ControlPanel.swift
        ├── HUDWindowController.swift
        ├── SoundLightApp.swift
        └── SystemControls.swift
```

| File | Responsibility |
| --- | --- |
| `ControlPanel.swift` | Shared pill component, adaptive visual tokens, and menu bar controls. |
| `HUDWindowController.swift` | HUD window placement, lifecycle, and entrance/exit animation. |
| `SoundLightApp.swift` | App entry point and routing between system changes and HUDs. |
| `SystemControls.swift` | CoreAudio integration, brightness integration, and system monitoring. |

## Development

Build the package from Terminal:

```bash
swift build
```

For interactive testing, keep the app running from Xcode and alternate between volume and brightness keys. Useful cases include single presses, held keys, mute/unmute, rapid direction changes, and fast switching between control types.

## Roadmap

- Developer ID signing and Apple notarization
- Optional launch at login
- Configurable HUD size, screen edge, and dismissal delay
- External display brightness through DDC
- Native app icon with default, dark, clear, and tinted appearances

## Contributing

Issues and focused pull requests are welcome. Please describe the macOS version, Mac model, display setup, and audio output device when reporting hardware-specific behavior.

---

<div align="center">

Built with SwiftUI, AppKit, CoreAudio, and CoreGraphics.

</div>
