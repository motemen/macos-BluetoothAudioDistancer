import SwiftUI

struct ContentView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    VStack(alignment: .leading) {
      KeyValueLine(
        key: "Input device uid",
        value: appState.activeAudioDevice?.uid
      )

      KeyValueLine(
        key: "Bluetooth device",
        value: appState.activeBluetoothDevice?.name
      )

      KeyValueLine(
        key: "Signal level",
        value: appState.activeBluetoothDevice?.signalLevel.description
      )

      KeyValueLine(
        key: "Input level set to",
        value: appState.inputVolumeSetTo?.description
      )
      .foregroundColor(appState.isCalibrationMode ? .gray : nil)

      Toggle(isOn: $appState.isCalibrationMode) {
        Text("Calibration mode")
      }
      .disabled(appState.activeBluetoothDevice == nil)
      .padding(.top)
      .font(.headline)

      KeyValueLine(
        key: "Max signal level",
        value: appState.maxLevel?.description
      )

      KeyValueLine(
        key: "Min signal level",
        value: appState.minLevel?.description
      )

      Divider()

      HStack {
        Spacer()
        Button(action: { self.terminateApp() },
        label: { Text("Quit") })
      }
    }
    .frame(width: 375)
    .padding()
  }

  private func terminateApp() {
    NSApplication.shared.terminate(self)
  }
}

private struct KeyValueLine: View {
  var key: String
  var value: String?

  var body: some View {
    HStack {
      Text("\(key):").frame(width: 140, alignment: .trailing)
      Spacer()
      Text(value ?? "-").font( /*@START_MENU_TOKEN@*/.headline /*@END_MENU_TOKEN@*/)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static let appState: AppState = {
    let s = AppState()
    s.activeAudioDevice = AudioDeviceInfo(
      deviceID: 666, uid: "de-ad-be-ef:input", isBluetooth: true)
    s.activeBluetoothDevice = BluetoothDeviceInfo(name: "My device", signalLevel: -30)
    return s
  }()

  static var previews: some View {
    ContentView().environmentObject(appState)
  }
}
