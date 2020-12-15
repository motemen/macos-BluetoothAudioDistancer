import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem?

  func applicationWillUpdate(_ notification: Notification) {
    if let window = NSApp.mainWindow {
      window.styleMask.subtract([.miniaturizable, .fullScreen, .resizable])
      window.tabbingMode = .disallowed
    }
  }

  /*
  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem?.button?.title = "D"

    let menu = NSMenu()

    let preferenceMenu = NSMenuItem(
      title: NSLocalizedString("Preference", comment: ""),
      action: #selector(showWindow), keyEquivalent: "")
    menu.addItem(preferenceMenu)

    statusItem?.menu = menu

    NSApp.setActivationPolicy(.accessory)
  }

  @objc func showWindow(sender: NSButton) {
    NSApp.activate(ignoringOtherApps: true)
    // TODO
  }
  */
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

@main
struct BluetoothAudioDistancerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @StateObject var core = AppCore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(core.appState)
    }
  }
}
