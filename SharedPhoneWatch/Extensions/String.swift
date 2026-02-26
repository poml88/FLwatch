//
//  String.swift
//  LibreWrist
//
//  Created by Peter Müller on 14.08.24.
//

import Foundation

extension String {

    var isBlank: Bool {
        allSatisfy({ $0.isWhitespace })
    }

    var attributed: AttributedString {
        try! AttributedString(markdown: self)
    }
    
    var SHA256: String { Data(self.utf8).sha256Hex }

}
