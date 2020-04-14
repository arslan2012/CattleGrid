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
                    Text("\(tagStore.progress * 100, specifier: "%.2f")%")
                        .font(.subheadline)
                }
            }
            if self.tagStore.error != "" {
                Text(self.tagStore.error)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            //File selector
            NavigationView {
                if (tagStore.amiibos.count > 0) {
                    List(tagStore.amiibos, id:\.path) { amiibo in
                        Text(amiibo.lastPathComponent).onTapGesture {
                            self.tagStore.load(amiibo)
                        }
                        .foregroundColor(self.selected(amiibo) ? .primary : .secondary)
                    }
                    .hiddenNavigationBarStyle()
                } else {
                    Text("No figures.").font(.headline)
                    Text("https://support.apple.com/en-us/HT201301").font(.subheadline)
                }
            }
            .onAppear(perform: self.tagStore.start)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentColor, lineWidth: 0.3)
            )

            //button to say 'go'
            Button(action: self.tagStore.scan) {
                Image(systemName: "square.and.pencil")
                    .font(.largeTitle)
                    .disabled(self.tagStore.selected == nil)
                    .padding()
            }
            .disabled(self.tagStore.selected == nil)
            Text("© Eric Betts 2020")
                .font(.footnote)
        }
        .padding()
    }

    func selected(_ amiibo: URL) -> Bool {
        return (amiibo.lastPathComponent == self.tagStore.selected?.lastPathComponent)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(TagStore.shared)
    }
}

