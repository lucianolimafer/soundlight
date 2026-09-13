import AppKit
import SwiftUI

@main
struct SoundLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ControlPanel()
                .environmentObject(appDelegate.controls)
        } label: {
            Image(systemName: "slider.vertical.3")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controls = SystemControls()
    private var volumeHUD: HUDWindowController?
    private var brightnessHUD: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let volumeHUD = HUDWindowController(controls: controls, kind: .volume)
        let brightnessHUD = HUDWindowController(controls: controls, kind: .brightness)
        controls.onSystemControlChanged = { [weak volumeHUD, weak brightnessHUD] kind in
            switch kind {
            case .volume: volumeHUD?.show()
            case .brightness: brightnessHUD?.show()
            }
        }
        self.volumeHUD = volumeHUD
        self.brightnessHUD = brightnessHUD
    }

    func applicationWillTerminate(_ notification: Notification) {
        controls.stopMonitoring()
    }
}
