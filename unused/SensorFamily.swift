////
////  SensorFamily.swift
////  LibreWrist
////
////  Created by Peter Müller on 19.08.24.
////
//
//import Foundation
//
//enum SensorFamily: Int, Codable {
//    case unknown = -1
//    case libre1 = 0
//    case librePro = 1
//    case libre2 = 3
//    case libreSense = 7
//    case libre3 = 46
//
//    // MARK: Lifecycle
//
//    init() {
//        self = .unknown
//    }
//
//    init(_ family: Int) {
//        switch family {
//        case 0:
//            self = .libre1
//        case 1:
//            self = .librePro
//        case 3:
//            self = .libre2
//        case 7:
//            self = .libreSense
//        default:
//            self = .unknown
//        }
//    }
//
//    init(_ patchInfo: Data) {
//        let family = Int(patchInfo[2] >> 4)
//
//        switch family {
//        case 0:
//            self = .libre1
//        case 1:
//            self = .librePro
//        case 3:
//            self = .libre2
//        case 7:
//            self = .libreSense
//        default:
//            self = .unknown
//        }
//    }
//
//    // MARK: Internal
//
//    var description: String {
//        switch self {
//        case .libre1:
//            return "Libre 1"
//        case .librePro:
//            return "Libre Pro/H"
//        case .libre2:
//            return "Libre 2"
//        case .libreSense:
//            return "Libre Sense"
//        case .libre3:
//            return "Libre 3"
//        default:
//            return "Unknown"
//        }
//    }
//
////    var localizedDescription: String {
////        LocalizedString(description)
////    }
//}
