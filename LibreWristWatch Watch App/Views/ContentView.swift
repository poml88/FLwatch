//
//  ContentView.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI


struct ContentView: View {
    
    @StateObject var watchConnector = WatchConnectivityManager()
    
    @State var selected = "Home"
    

        var body: some View {
            TabView(selection: $selected) {
//                WatchAppActionView()
//                    .tag("Action")
                WatchAppHomeView()
                    .tag("Home")
                WatchAppNightView()
                    .tag("NightView")
//                WatchAppSettingsView()
//                    .tag("Connect")
                WatchAppDonateView()
                    .tag("Donate")
                
                
            }
            .tabViewStyle(.page)
        }
    }


#Preview {
    ContentView()
//        .environment(LibreLinkUpHistory.mock)
}
