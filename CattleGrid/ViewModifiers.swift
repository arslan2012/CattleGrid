//
//  ViewModifiers.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/12/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import Foundation
import SwiftUI

//https://stackoverflow.com/a/60492133
struct HiddenNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarHidden(true)
    }
}

extension View {
    func hiddenNavigationBarStyle() -> some View {
        ModifiedContent(content: self, modifier: HiddenNavigationBar())
    }
}
