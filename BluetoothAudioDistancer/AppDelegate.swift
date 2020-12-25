import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var popover: NSPopover!
    private var statusBarItem: NSStatusItem!
    private var core = AppCore()

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let contentView = ContentView()
            .environmentObject(core.appState)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover

        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right",
                                   accessibilityDescription: "Open")
            button.action = #selector(togglePopover(_:))
        }
    }

    func applicationWillUpdate(_ notification: Notification) {
      if let window = NSApp.mainWindow {
        window.styleMask.subtract([.miniaturizable, .fullScreen, .resizable])
        window.tabbingMode = .disallowed
      }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
}

class AppCore: ObservableObject {
  @Published var appState: AppState

  @Published var watcher: BluetoothAudioWatcher

  init() {
    let appState = AppState()
    self.appState = appState
    self.watcher = BluetoothAudioWatcher(appState: appState)
  }
}
