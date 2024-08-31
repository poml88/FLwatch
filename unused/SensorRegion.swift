////
////  SensorRegion.swift
////  LibreWrist
////
////  Created by Peter Müller on 19.08.24.
////
//
//import Foundation
//
//enum SensorRegion: String, Codable {
//    case unknown = "0 - Unknown"
//    case european = "1 - European"
//    case usa = "2 - USA"
//    case australian = "4 - Australia/Canada"
//    case eastern = "8 - Eastern"
//
//    // MARK: Lifecycle
//
//    init() {
//        self = .unknown
//    }
//
//    init(_ region: UInt8) {
//        switch region {
//        case 0:
//            self = .unknown
//        case 1:
//            self = .european
//        case 2:
//            self = .usa
//        case 4:
//            self = .australian
//        case 8:
//            self = .eastern
//        default:
//            self = .unknown
//        }
//    }
//
//    init(_ patchInfo: Data) {
//        switch patchInfo[3] {
//        case 0:
//            self = .unknown
//        case 1:
//            self = .european
//        case 2:
//            self = .usa
//        case 4:
//            self = .australian
//        case 8:
//            self = .eastern
//        default:
//            self = .unknown
//        }
//    }
//
//    // MARK: Internal
//
//    var description: String {
//        rawValue
//    }
//
////    var localizedDescription: String {
////        LocalizedString(rawValue)
////    }
//}
