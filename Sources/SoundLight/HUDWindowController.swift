import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class HUDWindowController {
    private let panel: NSPanel
    private let kind: SystemControlKind
    private let animationState: HUDAnimationState
    private var hideWorkItem: DispatchWorkItem?
    private var isPresented = false
    private var isExiting = false
    private var animationID = 0

    init(controls: SystemControls, kind: SystemControlKind) {
        self.kind = kind
        self.animationState = HUDAnimationState()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: PillMetrics.width, height: PillMetrics.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDContent(
            controls: controls,
            kind: kind,
            animationState: animationState
        ))
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let visible = screen.visibleFrame
        let horizontalMargin: CGFloat = 28
        let targetX = kind == .brightness
            ? visible.minX + horizontalMargin
            : visible.maxX - panel.frame.width - horizontalMargin
        let targetOrigin = NSPoint(
            x: targetX,
            y: visible.midY - panel.frame.height / 2
        )
        let outsideOrigin = NSPoint(
            x: kind == .brightness ? visible.minX - panel.frame.width : visible.maxX,
            y: targetOrigin.y
        )
        let targetFrame = NSRect(origin: targetOrigin, size: panel.frame.size)
        let outsideFrame = NSRect(origin: outsideOrigin, size: panel.frame.size)

        hideWorkItem?.cancel()
        let shouldAnimateEntrance = !isPresented || isExiting
        if shouldAnimateEntrance {
            animationID += 1
            isExiting = false
        }
        let currentAnimationID = animationID
        panel.alphaValue = 1

        if shouldAnimateEntrance {
            isPresented = true
            animationState.isVisible = false
            panel.setFrame(outsideFrame, display: true)
            panel.orderFrontRegardless()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                guard let self, self.animationID == currentAnimationID else { return }
                self.animationState.isVisible = true
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.30
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.panel.animator().setFrame(targetFrame, display: true)
                }
            }
        } else {
            animationState.isVisible = true
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.animationID == currentAnimationID else { return }
            self.isExiting = true
            self.animationState.isVisible = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.26
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.panel.animator().setFrame(outsideFrame, display: true)
            } completionHandler: {
                Task { @MainActor [weak self] in
                    guard let self, self.animationID == currentAnimationID else { return }
                    self.isExiting = false
                    self.isPresented = false
                    self.panel.orderOut(nil)
                }
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: work)
    }
}

@MainActor
final class HUDAnimationState: ObservableObject {
    @Published var isVisible = false
}

struct HUDContent: View {
    @ObservedObject var controls: SystemControls
    let kind: SystemControlKind
    @ObservedObject var animationState: HUDAnimationState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        CapsuleSlider(
            value: kind == .volume ? $controls.volume : $controls.brightness,
            symbol: kind.symbol(value: kind == .volume ? controls.volume : controls.brightness),
            tint: kind.tint(colorScheme: colorScheme, contrast: colorSchemeContrast),
            accessibilityLabel: kind.accessibilityLabel
        )
        .scaleEffect(animationState.isVisible ? 1 : 0.5)
        .animation(
            .spring(response: 0.30, dampingFraction: 0.82),
            value: animationState.isVisible
        )
    }
}
