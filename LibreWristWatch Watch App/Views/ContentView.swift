//
//  ContentView.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI


struct ContentView: View {
    
//    @StateObject var watchConnector = WatchConnectivityManager()
    
    @State var selected = "Home"
    @Environment(\.workoutModeStore) private var workoutModeStore
    

        var body: some View {
            TabView(selection: $selected) {
//                WatchAppActionView()
//                    .tag("Action")
                WatchAppHomeView()
                    .tag("Home")
                WatchAppWorkoutView()
                    .tag("Workout")
                WatchAppNightView()
                    .tag("NightView")
//                WatchAppSettingsView()
//                    .tag("Connect")
                WatchAppDonateView()
                    .tag("Donate")
                
                
            }
            .tabViewStyle(.page)
            .onAppear {
                if workoutModeStore.isActive {
                    selected = "Workout"
                }
            }
            .onChange(of: workoutModeStore.isActive) { _, isActive in
                if isActive {
                    selected = "Workout"
                }
            }
        }
    }


#Preview {
    ContentView()
        .environment(\.locale, .init(identifier: "en"))
//        .environment(LibreLinkUpHistory.mock)
}
