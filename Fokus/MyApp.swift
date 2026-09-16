import SwiftUI
import AppKit

// MARK: - App Delegate for Quitting on Window Close
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor())
                .frame(minWidth: 680, minHeight: 540)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 680)
    }
}

// MARK: - Window Accessor for Native Glass & Fullscreen Support
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.collectionBehavior.insert([.fullScreenPrimary])
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
