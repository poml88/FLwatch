//
//  LibreWristWidgetBundle.swift
//  LibreWristWidget
//
//  Created by Peter Müller on 02.10.24.
//

import WidgetKit
import SwiftUI

@main
struct LibreWristWidgetBundle: WidgetBundle {
    var body: some Widget {
        LibreWristWidget()
        FLwatchGraphWidget()
        FLwatchFullGraphWidget()
        FLWatchLiveActivityWidget()
    }
}
