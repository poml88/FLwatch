//
//  MeasurementColor.swift
//  LibreWrist
//
//  Created by Peter Müller on 28.08.24.
//

import SwiftUI


enum MeasurementColor: Int, Codable {
    case green  = 1
    case yellow = 2
    case orange = 3
    case red    = 4
    case gray   = 5
}


extension MeasurementColor {
    var color: Color {
        switch self {
        case .green:  .green
        case .yellow: .yellow
        case .orange: .orange
        case .red:    .red
        case .gray:   .gray //Color(white: 0.1)
        }
    }
}
