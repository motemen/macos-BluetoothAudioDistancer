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
  @Published var activeAudioDevice: AudioDeviceInfo?
  @Published var activeBluetoothDevice: BluetoothDeviceInfo?
  @Published var inputVolumeSetTo: Float?

  @Published var minLevel: BluetoothHCIRSSIValue? {
    didSet {
      if let minLevel = minLevel {
        UserDefaults.standard.set(minLevel, forKey: "minLevel")

      } else {
        UserDefaults.standard.removeObject(forKey: "minLevel")
      }
    }
  }
  @Published var maxLevel: BluetoothHCIRSSIValue? {
    didSet {
      if let maxLevel = maxLevel {
        UserDefaults.standard.set(maxLevel, forKey: "maxLevel")

      } else {
        UserDefaults.standard.removeObject(forKey: "maxLevel")
      }

    }
  }

  @Published var isCalibrationMode: Bool = false

  init() {
    minLevel = (UserDefaults.standard.object(forKey: "minLevel") as? Int).flatMap {
      BluetoothHCIRSSIValue(exactly: $0)
    }
    maxLevel = (UserDefaults.standard.object(forKey: "maxLevel") as? Int).flatMap {
      BluetoothHCIRSSIValue(exactly: $0)
    }
  }
}
