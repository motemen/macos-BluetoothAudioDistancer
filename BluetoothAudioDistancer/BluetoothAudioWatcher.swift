import Combine
import CoreAudio
import Foundation
import IOBluetooth

class BluetoothAudioWatcher: ObservableObject {
  var appState: AppState

  static let NUM_DATAPOINTS = 5

  private var cancellables = [AnyCancellable]()

  init(appState: AppState) {
    self.appState = appState

    cancellables.append(
      appState.$isCalibrationMode.sink { newMode in
        if newMode {
          appState.maxLevel = nil
          appState.minLevel = nil
        }
      }
    )

    start()
  }

  func start() {
    cancellables.append(
      Timer.TimerPublisher(
        interval: TimeInterval(1),
        runLoop: .main,
        mode: .default
      )
      .autoconnect()
      .map { [weak self] _ in
        self?.update()
        return self?.appState.activeBluetoothDevice?.signalLevel
      }
      .scan(
        [BluetoothHCIRSSIValue?](),
        { ($0 + [$1]).suffix(BluetoothAudioWatcher.NUM_DATAPOINTS) }  // use last 5 datapoints
      )
      .sink { [weak self] levels in
        let validLevels = levels.compactMap({ $0 })
        if validLevels.count == BluetoothAudioWatcher.NUM_DATAPOINTS {
          let averageLevel = validLevels.reduce(0, { $0 + Int($1) }) / validLevels.count
          self?.syncInputVolumeLevel(signalLevel: BluetoothHCIRSSIValue(averageLevel))
        }
      }
    )
  }

  func update() {
    do {
      try updateActiveInputDevice()
    } catch let error {
      print(error)
    }

    updateBluetoothDevice()
  }

  private func audioObjectGetProp<T>(
    objectID: AudioObjectID, address: AudioObjectPropertyAddress, value: inout T
  ) throws {
    var addressRef = address
    var size = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioObjectGetPropertyData(objectID, &addressRef, 0, nil, &size, &value)
    if status != noErr {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func updateActiveInputDevice() throws {
    /// デフォルトの音声入力デバイスを取得
    // https://stackoverflow.com/a/11069595/4344474
    var deviceID: AudioDeviceID = 0
    try! audioObjectGetProp(
      objectID: AudioObjectID(kAudioObjectSystemObject),
      address: AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
      ),
      value: &deviceID
    )

    /// https://stackoverflow.com/a/32018550/4344474
    // Bluetooth かどうか調べる
    var transportType: UInt32 = 0
    try! audioObjectGetProp(
      objectID: deviceID,
      address: AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMaster
      ),
      value: &transportType
    )

    // DeviceUID 知りたい
    var uid: NSString = ""
    try! audioObjectGetProp(
      objectID: deviceID,
      address: AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMaster
      ),
      value: &uid
    )

    appState.activeAudioDevice = AudioDeviceInfo(
      deviceID: deviceID, uid: uid as String,
      isBluetooth: transportType == kAudioDeviceTransportTypeBluetooth)
  }

  private func getBluetoothDevice(for audioDevice: AudioDeviceInfo) -> BluetoothDeviceInfo? {
    if audioDevice.isBluetooth == false {
      return nil
    }

    guard let devices = IOBluetoothDevice.pairedDevices() else {
      return nil
    }

    for item in devices {
      guard let device = item as? IOBluetoothDevice else {
        continue
      }

      if device.isConnected() {
        if device.addressString + ":input" == audioDevice.uid {
          return BluetoothDeviceInfo(name: device.name, signalLevel: device.rawRSSI())
        }
      }
    }

    return nil
  }

  private func updateBluetoothDevice() {
    guard let audioDevice = appState.activeAudioDevice else {
      return
    }

    appState.activeBluetoothDevice = getBluetoothDevice(for: audioDevice)
  }

  private func syncInputVolumeLevel(signalLevel: BluetoothHCIRSSIValue) {
    guard let audioDevice = appState.activeAudioDevice else {
      return
    }

    if appState.isCalibrationMode {
      appState.maxLevel = appState.maxLevel.map { max($0, signalLevel) } ?? signalLevel
      appState.minLevel = appState.minLevel.map { min($0, signalLevel) } ?? signalLevel
      return
    }

    if let minRSSI = appState.minLevel, let maxRSSI = appState.maxLevel {
      if maxRSSI != minRSSI {
        let x = Float(signalLevel - minRSSI) / Float(maxRSSI - minRSSI)
        var volume = min(1.0, max(0.0, (1 - pow(1 - x, 2)) * 1.2))  // * 1.2 はマージン
        var addr = AudioObjectPropertyAddress(
          mSelector: kAudioDevicePropertyVolumeScalar,
          mScope: kAudioDevicePropertyScopeInput,
          mElement: kAudioObjectPropertyElementMaster
        )
        print("Volume set to: \(volume)")
        appState.inputVolumeSetTo = volume
        AudioObjectSetPropertyData(
          audioDevice.deviceID, &addr, 0, nil, UInt32(MemoryLayout.size(ofValue: volume)), &volume
        )
      }
    }

  }
}
