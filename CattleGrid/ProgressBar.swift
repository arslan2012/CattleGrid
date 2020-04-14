//
//  ProgressBar.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/13/20.
//

import Foundation
import SwiftUI

// https://www.simpleswiftguide.com/how-to-build-linear-progress-bar-in-swiftui/
struct ProgressBar: View {
    let value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width , height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color(UIColor.systemTeal))

                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color(UIColor.systemBlue))
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
}
