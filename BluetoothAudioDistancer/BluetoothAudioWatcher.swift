import Foundation
import CoreAudio
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
        if let deviceInfo = try? getActiveInputDevice() {
            checkBluetoothDevices(deviceInfo: deviceInfo)
        }

        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(3), repeats: true) { [self] (_) in
            if let deviceInfo = try? getActiveInputDevice() {
                checkBluetoothDevices(deviceInfo: deviceInfo)
            }
        }
    }

    private func audioObjectGetProp<T>(objectID: AudioObjectID, address: AudioObjectPropertyAddress, value: inout T) -> OSStatus {
        var addressRef = address
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(objectID, &addressRef, 0, nil, &size, &value)
    }

    func getActiveInputDevice() throws -> AudioDeviceInfo? {
        /// デフォルトの音声入力デバイスを取得
        // https://stackoverflow.com/a/11069595/4344474
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout.size(ofValue: deviceID))
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)

        if status != noErr {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        print("Got deviceID: \(deviceID)")

        /// https://stackoverflow.com/a/32018550/4344474
        // Bluetooth かどうか調べる
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        )

        var transportType: UInt32 = 0
        size = UInt32(MemoryLayout.size(ofValue: transportType))
        status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transportType)

        if status != noErr {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        if transportType != kAudioDeviceTransportTypeBluetooth {
            print("Not a bluetooth device")
            return nil
        }

        // DeviceUID 知りたい
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        )

        var uid: NSString = ""
        size = UInt32(MemoryLayout.size(ofValue: uid))
        status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &uid)

        if status != noErr {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        if let match = try? NSRegularExpression(pattern: "^(.+):input$").firstMatch(in: uid as String, range: NSRange(location: 0, length: uid.length)) {

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
                    return BluetoothDeviceInfo(name: device.name, rssi: device.rssi())
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

        if isCalibrationMode {
            maxRSSI = maxRSSI.map { m in m > bluetoothDevice.rssi ? m : bluetoothDevice
                .rssi } ?? bluetoothDevice.rssi
            minRSSI = minRSSI.map { m in m < bluetoothDevice.rssi ? m : bluetoothDevice
                .rssi } ?? bluetoothDevice.rssi

        }
        
        print("Device: name=\(String(describing: bluetoothDevice.name)) rssi=\(bluetoothDevice.rssi)")

        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeDecibels,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        )

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: volume))
        var status = AudioObjectGetPropertyData(deviceInfo.deviceID, &addr, 0, nil, &size, &volume)
        print("VolumeDecibels: \(volume)")
    }
}
