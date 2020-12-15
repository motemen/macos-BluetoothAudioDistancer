import Combine
import CoreAudio
import Foundation
import IOBluetooth

struct AudioDeviceInfo {
  let deviceID: AudioDeviceID
  let uid: String
  let isBluetooth: Bool
}

struct BluetoothDeviceInfo {
  let name: String?
  let signalLevel: BluetoothHCIRSSIValue
}

class AppState: ObservableObject {
  @Published var isCalibrationMode: Bool = false

  @Published var activeAudioDevice: AudioDeviceInfo?
  @Published var activeBluetoothDevice: BluetoothDeviceInfo?
  // TODO: save (per device uid)
  @Published var maxLevel: BluetoothHCIRSSIValue?
  @Published var minLevel: BluetoothHCIRSSIValue?
  @Published var inputVolumeSetTo: Float?
}
