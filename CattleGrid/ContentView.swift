//
//  ContentView.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/10/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tagStore: TagStore
    var body: some View {
        VStack(alignment: .center) {
            //File selector
            //button to say 'go'
            Text("Hello, World!")
            Button(action: self.tagStore.start) {
                 Image(systemName: "square.and.pencil")
                .resizable()
                .aspectRatio(contentMode: .fit)
            }
        }
        .padding()        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(TagStore.shared)
    }
}
