//
//  ViewModifiers.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.08.25.
//

import SwiftUI
//TODO:  ("Work not finished")

struct CustomAnnotationPosition: ViewModifier {
    let timeStamp: Double
    
    func body(content: Content) -> some View {
        if timeStamp > Date().timeIntervalSince1970 - 30 * 60 {
            content
                .background(Color.red)
        } else {
            content
                . background(Color.blue)
        }
           
    }
}

extension View {
    func customAnnotationPosition(timeStamp: Double) -> some View {
        modifier(CustomAnnotationPosition(timeStamp: timeStamp))
    }
}



