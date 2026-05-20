//
//  WatchAppNightView.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI

 
struct WatchAppNightView: View {
    
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
    
//    @State private var currentIOB: Double = 0.0
        
    var body: some View {
        if libreLinkUpHistory.libreLinkUpGlucose.count > 0 {
//            let readingDate = libreLinkUpHistory.libreLinkUpGlucose[0].glucose.date

            VStack (spacing: -15) {
    //                if minutesSinceLastReading >= 3 {
    //                    Text("---")
    //                    .font(.system(size: 60)) //, weight: .bold
    //                    .minimumScaleFactor(0.1)
    //                    .padding()
    //                } else {
                Text("\(libreLinkUpHistory.libreLinkUpGlucose[0].glucose.value.units)")
                    .font(.system(size: 100)) //, weight: .bold
                    .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
                        .minimumScaleFactor(0.9)
    //                    .padding()
    //                }
                    
//                VStack (spacing: -10){
    //                    if minutesSinceLastReading >= 3 {
    //                        Text("---")
    //                            .font(.title)
    //                    } else {
                    Text("\(libreLinkUpHistory.libreLinkUpGlucose[0].trendArrow?.symbol ?? "--")")
                        .font(.system(size: 100)) //, weight: .bold
                        .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
                            .minimumScaleFactor(0.7)
    //                        .foregroundStyle(libreLinkUpHistory[0].color.color)
                    
                if currentIOBSingleton.currentIOB > 0 {
                    Text("\(currentIOBSingleton.currentIOB, specifier: "%.2f")u")
                        .font(.largeTitle)
                        .padding(.bottom, 20)
                }
                
//                TimelineView(.periodic(from: readingDate, by: 1)) { context in
//                    Text(elapsedTimeString(since: readingDate, now: context.date))
////                    .bold()
//                        .monospacedDigit()
//                        .lineLimit(1)
////                    .truncationMode(.head)
//                        .allowsTightening(true)
//                        .minimumScaleFactor(0.7)
//                        .frame(width: 50, alignment: .trailing)
//                }
                
//                Text(Date(), style: .timer)
//                    .padding(.top, 20)
                
    //                    }
                    //                    Text("\(lastReadingDate.toLocalTime())")
                    //                        .font(.system(size: 30, weight: .bold))
                    
    //                    if minutesSinceLastReading == 999 {
    //                        Text("-- min ago")
    //                    } else {
    //                        Text("\(minutesSinceLastReading) min ago")
    //                    }
//                }
//                .padding()
            }
            .overlay {
                if Date().timeIntervalSince(libreLinkUpHistory.lastReadingDate) >= LibreLinkUpService.shared.activeProvider.staleReadingAfter {
                    ZStack {
                        Color(white: 0, opacity: 0.5)
                        
                        VStack {
                            Image(systemName: "hourglass.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40)
                            
                            Text("No data since \(Int(Date().timeIntervalSince(libreLinkUpHistory.lastReadingDate) / 60)) min.")
                                .multilineTextAlignment(.center)
                        }
                        
                        
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                _ = LibreLinkUpService.shared.refreshHistoryFromPersistence()
            }
        }

    }
 
}

private func elapsedTimeString(since startDate: Date, now currentDate: Date) -> String {
    let elapsedSeconds = max(0, Int(currentDate.timeIntervalSince(startDate)))
    let minutes = elapsedSeconds / 60
    let seconds = elapsedSeconds % 60

    return "\(minutes):\(String(format: "%02d", seconds))"
}



#Preview {
    WatchAppNightView()
//        .environment(History.test)
}
