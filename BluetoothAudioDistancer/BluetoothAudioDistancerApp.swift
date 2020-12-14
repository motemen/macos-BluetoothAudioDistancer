import SwiftUI

@main
struct BluetoothAudioDistancerApp: App {
    @StateObject var blWatcher = BluetoothAudioWatcher()
    
    var body: some Scene {
        Settings {
           ContentView()
            .environmentObject(blWatcher)
        }
    }
}
