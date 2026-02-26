//
//  Data.swift
//  LibreWrist
//
//  Created by Peter Müller on 19.08.24.
//

import Foundation
import CryptoKit

extension Data {
    var hex: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    var string: String { String(decoding: self, as: UTF8.self) }
    
    var sha256Hex: String {
        let digest = CryptoKit.SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
      }

    
    var utf8: String {
        String(decoding: self, as: UTF8.self)
    }

    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)

        for i in 0 ..< length {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j ..< k]

            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }

        self = data
    }
}
