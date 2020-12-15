import CoreAudio
import Foundation
import IOBluetooth

class BluetoothAudioWatcher: ObservableObject {
  struct AudioDeviceInfo {
    let deviceID: AudioDeviceID
    let uid: String
  }

  struct BluetoothDeviceInfo {
    let name: String?
    let rssi: BluetoothHCIRSSIValue
  }

  var timer: Timer?
  var isCalibrationMode: Bool = false

  @Published var activeBluetoothDevice: BluetoothDeviceInfo?
  // TODO: save (per device uid)
  @Published var maxRSSI: BluetoothHCIRSSIValue?
  @Published var minRSSI: BluetoothHCIRSSIValue?

  init() {
    start()
  }

  func setCalibrationMode(mode: Bool) {
    if mode == true {
      maxRSSI = nil
      minRSSI = nil
    }

    isCalibrationMode = mode
  }

  func start() {
    // TODO: fix logic
    // TODO: sync to input levels
    if let deviceInfo = try? getActiveInputDevice() {
      checkBluetoothDevices(deviceInfo: deviceInfo)
    }

    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(3), repeats: true) { [self] (_) in
      if let deviceInfo = try? getActiveInputDevice() {
        checkBluetoothDevices(deviceInfo: deviceInfo)
      }
    }
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

  func getActiveInputDevice() throws -> AudioDeviceInfo? {
    /// デフォルトの音声入力デバイスを取得
    // https://stackoverflow.com/a/11069595/4344474
    /*
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout.size(ofValue: deviceID))
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        */

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

    print("Got deviceID: \(deviceID)")

    /// https://stackoverflow.com/a/32018550/4344474
    // Bluetooth かどうか調べる
    /*
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMaster
    )

    var transportType: UInt32 = 0
    var size = UInt32(MemoryLayout.size(ofValue: transportType))
    status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transportType)
 */
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

    if transportType != kAudioDeviceTransportTypeBluetooth {
      print("Not a bluetooth device")
      return nil
    }

    // DeviceUID 知りたい
    /*
    addr = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMaster
    )

    var uid: NSString = ""
    size = UInt32(MemoryLayout.size(ofValue: uid))
    status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &uid)
*/

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

    if let match = try? NSRegularExpression(pattern: "^(.+):input$").firstMatch(
      in: uid as String, range: NSRange(location: 0, length: uid.length))
    {

      return AudioDeviceInfo(deviceID: deviceID, uid: uid.substring(with: match.range(at: 1)))
    } else {
      print("Unexpected uid: \(uid)")
      return nil
    }
  }

  func getActiveBluetoothDevice(deviceInfo: AudioDeviceInfo) -> BluetoothDeviceInfo? {
    guard let devices = IOBluetoothDevice.pairedDevices() else {
      return nil
    }

    for item in devices {
      guard let device = item as? IOBluetoothDevice else {
        continue
      }

      if device.isConnected() {
        if device.addressString == deviceInfo.uid {
          return BluetoothDeviceInfo(name: device.name, rssi: device.rawRSSI())
        }
      }
    }

    return nil
  }

  func checkBluetoothDevices(deviceInfo: AudioDeviceInfo) {
    // XXX
    activeBluetoothDevice = getActiveBluetoothDevice(deviceInfo: deviceInfo)

    guard let bluetoothDevice = activeBluetoothDevice else {
      return
    }

    let rssi = bluetoothDevice.rssi

    print("Device: name=\(String(describing: bluetoothDevice.name)) rssi=\(rssi)")

    var volume: Float32 = 0
    try! audioObjectGetProp(
      objectID: deviceInfo.deviceID,
      address: AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMaster
      ),
      value: &volume
    )
    print("Volume: \(volume)")

    if isCalibrationMode {
      maxRSSI = maxRSSI.map { max($0, rssi) } ?? rssi
      minRSSI = minRSSI.map { min($0, rssi) } ?? rssi
    } else {
      if let min_ = minRSSI, let max_ = maxRSSI {
        if max_ != min_ {
          var volume = min(1.0, max(0.0, Float(rssi - min_) / Float((max_ - min_))))

          var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
          )
          print("Volume set to: \(volume)")
          AudioObjectSetPropertyData(
            deviceInfo.deviceID, &addr, 0, nil, UInt32(MemoryLayout.size(ofValue: volume)), &volume)
        }

      }
    }

  }
}
