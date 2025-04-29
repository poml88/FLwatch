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
            
            Text("Siri integration is still higly experimental!\n\nSiri can tell you your blood glucose by saying: \"Siri, what is my glucose in FLwatch\", or \"What is my FLwatch glucose level\". In the shortcuts app you can create a shortcut for this action with any custom name, like \"Current glucose level\" and select \"show shortcut on watch\".\n\nSiri (hopefully) will also be able to record insulin injections for the IOB, but it is not fully working yet.\n\nExplore the options in the Shortcuts app.")
            
        }
        .padding(20)
        .frame(width: 300)
        .background((Color(.secondarySystemBackground)))
        .cornerRadius(10)
        
        Spacer()
            
    }
}

#Preview {
    PhoneAppSiriSheetView()
}
