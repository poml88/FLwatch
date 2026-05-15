//
//  ContentView.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI
import OSLog

struct ContentView: View {

//    @StateObject var watchConnector = WatchConnectivityManager()

    @State var selectedTab = "Home"
    @State private var showsProviderPicker: Bool = ContentView.shouldShowFirstLaunchPicker()

    var body: some View {
        TabView (selection:$selectedTab){

            PhoneAppHomeView()
                .tabItem {
                    Image(systemName: "house")
//                    Text ("Tab 1")
                }
                .tag("Home")


            PhoneAppConnectView()
//                .environmentObject(watchConnector)
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
        .fullScreenCover(isPresented: $showsProviderPicker) {
            PhoneAppCGMProviderPickerView { kind in
                LibreLinkUpService.shared.switchProvider(to: kind)
                selectedTab = "Connect"
                showsProviderPicker = false
            }
            .interactiveDismissDisabled(true)
        }
//        .padding()
    }

    /// First-launch picker is shown only when no provider has been chosen and
    /// no LibreLinkUp credentials carry over from a 2.0.6 install (decision 7.5).
    private static func shouldShowFirstLaunchPicker() -> Bool {
        let store = UserDefaults.group
        let providerKindIsExplicitlySet = store.object(forKey: DefaultsKey.cgmProviderKind.rawValue) != nil
        if providerKindIsExplicitlySet { return false }
        return store.username.isEmpty
    }
}



#Preview {
    ContentView()
//        .environment(History.test)
//        .environment(LibreLinkUpHistory.shared)
//        .environment(SensorSettingsSingleton.shared)
//        .environment(CurrentIOBSingleton.shared)
//        .environment(InsulinDeliveryHistorySingleton.shared)
        .environment(\.locale, .init(identifier: "en"))
}
