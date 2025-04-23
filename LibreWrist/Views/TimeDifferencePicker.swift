//
//  TimeDifferencePicker.swift
//  FLwatch
//
//  Created by Peter Müller on 20.04.25.
//

import SwiftUI

struct TimeDifferencePicker: View {
    
    @Environment(\.dismiss) var dismiss
    
    @State private var hour = 0
    @State private var minute = 0
    
    @Binding var pickerTimeStamp: Date

    let hours: [Int] = Array(stride(from: 0, to: 13, by: 1))
    let minutes: [Int] = Array(stride(from: 0, to: 60, by: 1))


    
    var body: some View {
        Button {
            dismiss()
        } label: {
            Text("Dismiss")
        }
        .buttonStyle(.bordered)
        .padding()
        
        VStack {
            HStack {
                VStack {
                    Picker("Hour", selection: $hour) {
                        ForEach(hours, id: \.self) {
                            Text("\($0)")
                        }
                    }
                    //                .labelsHidden()
                    .frame(width: 70)
                    .clipped()
                    Text("Hour")
                    //                                .foregroundColor(.blue)
                }
                VStack {
                    Picker("Minute", selection: $minute) {
                        ForEach(minutes, id: \.self) {
                            Text("\($0)")
                        }
                    }
                    .frame(width: 70)
                    .clipped()
                    
                    Text("Minute")
                }
            }
            
            
            Button {
                let selectedDate = Date().addingTimeInterval(TimeInterval(-hour * 3600 - minute * 60))
                print("Selected Date: \(selectedDate)")
                pickerTimeStamp = selectedDate
                dismiss()
            } label: {
                Text("Submit")
            }
            .buttonStyle(.bordered)
        }.frame(width: 300, height: 300)
//            .background(Color.black)
            .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .pickerStyle(.wheel)
    }
}

#Preview {
    TimeDifferencePicker(pickerTimeStamp: .constant(Date()))
}
