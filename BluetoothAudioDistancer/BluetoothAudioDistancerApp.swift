import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillUpdate(_ notification: Notification) {
    if let window = NSApplication.shared.mainWindow {
      window.styleMask.subtract([.miniaturizable, .fullScreen, .resizable])
      window.tabbingMode = .disallowed
    }
  }
}

@main
struct BluetoothAudioDistancerApp: App {
  @StateObject var blWatcher = BluetoothAudioWatcher()

  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(blWatcher)
    }
  }
}
