//
//  ContentView.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI
import OSLog

struct ContentView: View {
    
    @StateObject var watchConnector = WatchConnectivityManager()
    
    @State var selectedTab = "Home"
    
    
    
    var body: some View {
        TabView (selection:$selectedTab){
            
            PhoneAppHomeView()
                .tabItem { 
                    Image(systemName: "house")
//                    Text ("Tab 1")
                }
                .tag("Home")
            
            
            PhoneAppConnectView()
                .tabItem {
                    Image(systemName: "app.connected.to.app.below.fill")
//                    Text ("Tab 2")
                }
                .tag("Connect")
            
            PhoneAppSettingsView()
                .tabItem {
                    Image(systemName: "gear")
//                    Text ("Tab 2")
                }
                .tag("Settings")
            
            PhoneAppDonateView()
                .tabItem {
                    Image(systemName: "hand.thumbsup")
//                    Text ("Tab 3")
                }
                .tag("Donate")
        }
        .padding()
    }
}



#Preview {
    ContentView()
//        .environment(History.test)
        .environment(LibreLinkUpHistory.shared)
        .environment(SensorSettingsSingleton.shared)
}
