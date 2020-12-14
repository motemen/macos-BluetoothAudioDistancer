//
//  ContentView.swift
//  BluetoothAudioDistancer
//
//  Created by motemen on 2020/12/14.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var blWatcher: BluetoothAudioWatcher
    
    @State var isCalibrationMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            KeyValueLine(key: "Active device", value: blWatcher.activeBluetoothDevice?.name)
            KeyValueLine(key: "Signal level",
                         value: blWatcher.activeBluetoothDevice?.rssi.description)
            KeyValueLine(key: "Input level set to")
                .foregroundColor(isCalibrationMode ? .gray : nil)
            
            Toggle(isOn: $isCalibrationMode) {
                Text("Calibration mode")
            }.disabled(blWatcher.activeBluetoothDevice == nil)
            .padding(.top)
            .font(.headline)
            
            KeyValueLine(key: "Max signal level", value: blWatcher.maxRSSI?.description
            )
            KeyValueLine(key: "Min signal level", value: blWatcher.minRSSI?.description)
        }.padding()
        .onChange(of: isCalibrationMode) { isCalibrationMode in
            blWatcher.setCalibrationMode(mode: isCalibrationMode)
        }
        .frame(width: 375, height: 150)
    }
}

private struct KeyValueLine: View {
    var key: String
    var value: String?

    var body: some View {
        HStack {
            Text("\(key):").frame(width: 120, alignment: .trailing)
            Spacer()
            Text(value ?? "-").font(/*@START_MENU_TOKEN@*/.headline/*@END_MENU_TOKEN@*/)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
