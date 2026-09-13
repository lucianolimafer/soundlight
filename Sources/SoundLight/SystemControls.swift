import CoreAudio
import CoreGraphics
import Darwin
import Foundation

@MainActor
final class SystemControls: ObservableObject {
    @Published var volume: Double = 0 {
        didSet {
            guard !isRefreshing else { return }
            AudioController.setVolume(Float32(volume))
        }
    }

    @Published var brightness: Double = 0.5 {
        didSet {
            guard !isRefreshing else { return }
            BrightnessController.setBrightness(Float(brightness))
        }
    }

    private var isRefreshing = false
    private var monitorTimer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []
    private var lastObservedVolume: Double?
    private var lastObservedBrightness: Double?
    var onSystemControlChanged: ((SystemControlKind) -> Void)?

    init() {
        refresh()
        lastObservedVolume = volume
        lastObservedBrightness = brightness
        startMonitoring()
        observeSystemNotifications()
    }

    func refresh() {
        updatePublishedValues {
            volume = Double(AudioController.volume() ?? 0)
            brightness = Double(BrightnessController.brightness() ?? 0.5)
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        let center = DistributedNotificationCenter.default()
        notificationTokens.forEach(center.removeObserver)
        notificationTokens.removeAll()
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollSystemControls() }
        }
        monitorTimer?.tolerance = 0.01
    }

    private func observeSystemNotifications() {
        let center = DistributedNotificationCenter.default()
        let names = [
            Notification.Name("com.apple.BezelServices.BrightnessChanged"),
            Notification.Name("com.apple.sound.settingsChanged")
        ]
        notificationTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.pollSystemControls()

                    if name.rawValue.contains("Brightness") {
                        self.onSystemControlChanged?(.brightness)
                        for delay in [0.04, 0.10, 0.18] {
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                Task { @MainActor [weak self] in self?.pollSystemControls() }
                            }
                        }
                    }
                }
            }
        }
    }

    private func pollSystemControls() {
        if let newVolume = AudioController.volume().map(Double.init) {
            if let previous = lastObservedVolume, abs(newVolume - previous) > 0.002 {
                updatePublishedValues { volume = newVolume }
                onSystemControlChanged?(.volume)
            }
            lastObservedVolume = newVolume
        }

        if let newBrightness = BrightnessController.brightness().map(Double.init) {
            if let previous = lastObservedBrightness, abs(newBrightness - previous) > 0.002 {
                updatePublishedValues { brightness = newBrightness }
                onSystemControlChanged?(.brightness)
            }
            lastObservedBrightness = newBrightness
        }
    }

    private func updatePublishedValues(_ updates: () -> Void) {
        isRefreshing = true
        defer { isRefreshing = false }
        updates()
    }
}

enum SystemControlKind {
    case volume
    case brightness
}

private enum AudioController {
    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr ? device : nil
    }

    private static func volume(device: AudioDeviceID, element: AudioObjectPropertyElement) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    static func volume() -> Float32? {
        guard let device = defaultOutputDevice() else { return nil }
        if isMuted(device: device) == true { return 0 }
        if let master = volume(device: device, element: kAudioObjectPropertyElementMain) {
            return master
        }
        let channels = [
            volume(device: device, element: 1),
            volume(device: device, element: 2)
        ].compactMap { $0 }
        return channels.isEmpty ? nil : channels.reduce(0, +) / Float32(channels.count)
    }

    static func setVolume(_ value: Float32) {
        guard let device = defaultOutputDevice() else { return }
        if value > 0 { setMuted(false, device: device) }
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var newValue = min(1, max(0, value))
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(device, &address) else { continue }
            AudioObjectSetPropertyData(
                device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue
            )
        }
    }

    private static func isMuted(device: AudioDeviceID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        return status == noErr ? muted != 0 : nil
    }

    private static func setMuted(_ muted: Bool, device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
    }
}

private enum BrightnessController {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let displayServicesHandle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/A/DisplayServices",
        RTLD_LAZY
    )
    private static let coreDisplayHandle = dlopen(
        "/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay",
        RTLD_LAZY
    )

    private static let displayServicesGetter: GetBrightness? = symbol(
        displayServicesHandle, "DisplayServicesGetBrightness"
    )
    private static let displayServicesSetter: SetBrightness? = symbol(
        displayServicesHandle, "DisplayServicesSetBrightness"
    )
    private static let coreDisplayGetter: GetBrightness? = symbol(
        coreDisplayHandle, "CoreDisplay_Display_GetUserBrightness"
    )
    private static let coreDisplaySetter: SetBrightness? = symbol(
        coreDisplayHandle, "CoreDisplay_Display_SetUserBrightness"
    )

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static func brightness() -> Float? {
        var value: Float = 0.5
        if let getter = displayServicesGetter, getter(CGMainDisplayID(), &value) == 0 {
            return value
        }
        if let getter = coreDisplayGetter, getter(CGMainDisplayID(), &value) == 0 {
            return value
        }
        return nil
    }

    static func setBrightness(_ value: Float) {
        let value = min(1, max(0, value))
        if let setter = displayServicesSetter, setter(CGMainDisplayID(), value) == 0 { return }
        _ = coreDisplaySetter?(CGMainDisplayID(), value)
    }
}
