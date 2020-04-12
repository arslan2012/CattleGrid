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
            Text("CattleGrid").font(.largeTitle)
            if self.tagStore.lastPageWritten > 0 {
                HStack() {
                    ProgressBar(value: tagStore.progress).frame(height: 20)
                    Text(String(format: "%.2f%", tagStore.progress * 100)).font(.subheadline)
                }
            }
            if self.tagStore.error != "" {
                Text(self.tagStore.error)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            //File selector
            NavigationView {
                List(tagStore.amiibos) { amiibo in
                    Text(amiibo.filename).onTapGesture {
                        self.tagStore.load(amiibo)
                    }
                    .foregroundColor((amiibo.path == self.tagStore.selected?.path) ? .primary : .secondary)
                }
            }
            //button to say 'go'
            Button(action: self.tagStore.scan) {
                 Image(systemName: "square.and.pencil")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .disabled(self.tagStore.selected == nil)
                .padding()
            }
            .disabled(self.tagStore.selected == nil)
        }
        .padding()
        .onAppear(perform: self.tagStore.start)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(TagStore.shared)
    }
}

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
