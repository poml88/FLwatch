//
//  WatchAppSettings2View.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 30.08.24.
//

import SwiftUI
import StoreKit


struct WatchAppDonateView: View {
    
//    @State private var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
//    @AppStorage(SharedData.Keys.insulinDeliveryHistoryUpdated.key, store: SharedData.defaultsGroup) private var insulinDeliveryHistoryUpdated: Bool = false
    @Environment(\.insulinDeliveryHistorySingleton) var insulinDeliveryHistorySingleton

    
    private let productIDs = [
        "librewrist_4_99_a",
        "librewrist_9_99_a",
        "librewrist_24_99_a",
        "librewrist_49_99_a"
    ]
    
    var body: some View {
        ScrollView {
            VStack {
                Text("Buy the developer quality coffee beans!\n🤝☕️")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
                
                
                //                Text("paypal.me/lovemyhusky")
                //                .font(.caption)
                //                    .frame(maxWidth: 200, maxHeight: 50)
                //                    .foregroundColor(.black)
                //                    .background(.green)
                //                    .cornerRadius(10)
                
//                StoreView(ids: productIDs)
//                .productViewStyle(CustomProductStyle())
//                .frame(height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/)
                
                
                                ForEach(productIDs, id: \.self) { id in
                                    ProductView(id: id)
                                        .productViewStyle(CustomProductStyle())
                                }
                            
                
                
            }
            .padding(.top, -20)
            Text("Debug info:")
                .padding(.top, 40)
            let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
            Text("V\(versionNumber).\(buildNumber)")
            
            let systemVersion = WKInterfaceDevice.current().systemVersion
            let systemName = WKInterfaceDevice.current().systemName
            let model = WKInterfaceDevice.current().model
            let name = WKInterfaceDevice.current().name
            Text("\(systemName) \(systemVersion) on \(name)")
            if insulinDeliveryHistorySingleton.insulinDeliveryHistory.count > 0 {
                Text("\nInsulin history:")
                ForEach(insulinDeliveryHistorySingleton.insulinDeliveryHistory, id: \.id) {item in
                    let timeInterval = Date(timeIntervalSince1970: item.timeStamp).timeIntervalSinceNow
                    let timeSinceInjection = Duration(
                        secondsComponent: Int64(-timeInterval),
                        attosecondsComponent: 0
                    ).formatted(.time(pattern: .hourMinute))  // "2:05"
                    
                    Text("Time: \(Date(timeIntervalSince1970: item.timeStamp).toLocalTime())  (\(timeSinceInjection) h)      Units: \(item.insulinUnits, specifier: "%.1f")")
                }
            }
            
        }
        //        .onAppear() {
        //            insulinDeliveryHistory = UserDefaults.group.insulinDeliveryHistory ?? []
        //        }
    }
}

struct CustomProductStyle: ProductViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        switch configuration.state {
        case .loading:
            ProgressView()
        case .success(let product):
            Button {
                configuration.purchase()
            } label: {
                VStack(spacing: 2) {
                    Text(product.displayName)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(product.displayPrice)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
        default:
            Text("Something went wrong...")
        }
    }
}



    
#Preview {
    WatchAppDonateView()
}

