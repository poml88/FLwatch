//
//  PhoneAppSiriSheetView.swift
//  FLwatch
//
//  Created by Peter Müller on 29.04.25.
//

import SwiftUI

struct PhoneAppSiriSheetView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            Button {
                dismiss()
            } label: {
                Text("Dismiss")
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Spacer()
            
            VStack (spacing: 30){
                Text("Siri integration")
                    .font(.title)
                
                let longString: LocalizedStringKey = """
                Siri integration is still work in progress!
                
                Siri can tell you your blood glucose and trend by saying: \"Siri, what is my glucose in FLwatch\", or \"What is my FLwatch glucose level\".
                
                Since Siri has sometimes trouble understanding \"FLwatch\" (she always understands \"Apple watch\") you can also use \"glucose monitor\" as an app name synonym: \"Siri, what is my glucose in glucose monitor\", or \"What is my glucose monitor glucose level\".
                
                In the shortcuts app you can create a shortcut for this action with any custom name, like \"Current glucose level\" and select \"Show on Apple Watch\" to make the command work on the watch as well. If you then say: \"Hey Siri, current glucose level\", Siri will read the value and trend to you.
                
                Siri is also able to record insulin units for the IOB calculation.
                
                Explore the options in the Shortcuts app.
                
                Here is the full list of phrases:
                
                What is my glucose in FLwatch
                What's my glucose in FLwatch
                What is my glucose level in FLwatch
                What's my glucose level in FLwatch
                What is my FLwatch glucose
                What's my FLwatch glucose
                What is my FLwatch glucose level
                What's my FLwatch glucose level
                FLwatch get current blood glucose
                FLwatch what's my current blood glucose
                What's my current blood glucose in FLwatch
                
                FLwatch record insulin
                FLwatch note insulin
                FLwatch add insulin
                XX insulin units in FLwatch
                FLwatch XX unit
                FLwatch XX units
                XX unit FLwatch
                XX units FLwatch
                """
                Text(longString)
                
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background((Color(.secondarySystemBackground)))
            .cornerRadius(10)
            
            Spacer()
            
        }
        .padding(10)
    }
}

#Preview {
    PhoneAppSiriSheetView()
}
