//
//  PhoneAppDonateView.swift
//  LibreWrist
//
//  Created by Peter Müller on 01.08.24.
//

import SwiftUI
import StoreKit

struct PhoneAppDonateView: View {
    
    private let productIDs = [
        "librewrist_4_99_a",
        "librewrist_9_99_a",
        "librewrist_24_99_a",
        "librewrist_49_99_a"
    ]
    
    var body: some View {
        VStack (spacing: 15) {
            Image("coffeeBeans")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
            Text("If you like this app, buy the developer quality coffee beans!\n🤝☕️")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            
            ForEach(productIDs, id: \.self) { id in
                ProductView(id: id)
                    .productViewStyle(CustomProductStyle())
            }
        }
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
                VStack {
                    //                    Text(verbatim: "\(product.displayName) \(product.displayPrice)")
//                    Text(verbatim: product.displayName)
//                    Text(verbatim: product.displayPrice)
                    //                        .font(.caption2)
                    
                    VStack(spacing: 2) {
                        Text(product.displayName)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(product.displayPrice)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                }
                .frame(maxWidth: .infinity)
                
                
            }
            
            .buttonStyle(.bordered)
            
            
        default:
            Text("Something went wrong...")
        }
    }
}

#Preview {
    PhoneAppDonateView()
}
