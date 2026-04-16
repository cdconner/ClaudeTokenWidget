import SwiftUI
import AppKit

@main
struct ClaudeTokenWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private let store = UsageStore()
    private var frameObservers: [NSObjectProtocol] = []
    private var signalSources: [DispatchSourceSignal] = []

    private static let frameDefaultsKey = "panelFrame"
    private static let defaultSize = NSSize(width: 300, height: 220)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let frame = Self.restoredFrame() ?? Self.defaultFrame()
        let panel = FloatingPanel(contentRect: frame)
        let hosting = NSHostingView(rootView: ContentView().environmentObject(store))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.setFrame(frame, display: false)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        observeFrameChanges(on: panel)
        installSignalHandlers()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installSignalHandlers() {
        // Route SIGTERM/SIGINT through NSApp.terminate so applicationWillTerminate fires
        // and any last-chance state (like the panel frame) gets saved.
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let panel { Self.saveFrame(panel.frame) }
        frameObservers.forEach(NotificationCenter.default.removeObserver)
        frameObservers.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func observeFrameChanges(on panel: NSPanel) {
        let nc = NotificationCenter.default
        let save: @Sendable (Notification) -> Void = { notification in
            MainActor.assumeIsolated {
                guard let window = notification.object as? NSWindow else { return }
                AppDelegate.saveFrame(window.frame)
            }
        }
        frameObservers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main, using: save))
        frameObservers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main, using: save))
    }

    private static func saveFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: frameDefaultsKey)
    }

    private static func restoredFrame() -> NSRect? {
        guard let str = UserDefaults.standard.string(forKey: frameDefaultsKey) else { return nil }
        let frame = NSRectFromString(str)
        guard frame.size.width > 0, frame.size.height > 0 else { return nil }
        return isFrameOnScreen(frame) ? frame : nil
    }

    private static func isFrameOnScreen(_ frame: NSRect) -> Bool {
        // Require at least a 40x40 sliver of the frame to intersect some screen's visible area,
        // so a disconnected monitor doesn't leave the panel stranded off-screen.
        for screen in NSScreen.screens {
            let intersection = screen.visibleFrame.intersection(frame)
            if intersection.width >= 40, intersection.height >= 40 { return true }
        }
        return false
    }

    private static func defaultFrame() -> NSRect {
        let size = defaultSize
        guard let screen = NSScreen.main else {
            return NSRect(origin: NSPoint(x: 100, y: 100), size: size)
        }
        let visible = screen.visibleFrame
        let margin: CGFloat = 20
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.maxY - size.height - margin
        )
        return NSRect(origin: origin, size: size)
    }
}

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.minSize = NSSize(width: 260, height: 160)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
