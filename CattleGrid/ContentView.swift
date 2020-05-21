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
    #if JAILBREAK
    let warning = "your phone needs to be at least iphone7 or above and iOS 13+ to use this app"
    #else
    let warning = "your phone needs to be at least iphone7 or above and iOS 13+ to use this app, or maybe the app's 'entitlements' is not correctly signed"
    #endif
    
    var body: some View {
        VStack(alignment: .center) {
            if (tagStore.readingAvailable) {
                MainScreen(tagStore: _tagStore)
            } else {
                Text(warning)
                    .foregroundColor(.red)
                    .font(.largeTitle)
                    .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(TagStore.shared)
    }
}

struct MainScreen: View {
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
            .onDisappear(perform: self.tagStore.stop)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentColor, lineWidth: 0.3)
            )

            //button to say 'go'
            Button(action: self.tagStore.scan) {
                Image(systemName: "arrow.down.doc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:100, height:100)
                    .disabled(self.tagStore.selected == nil)
                    .padding()
            }
            .disabled(self.tagStore.selected == nil)
            Text("© Eric Betts 2020")
                .font(.footnote)
                .fontWeight(.light)
        }
        .padding()
    }

    func selected(_ amiibo: URL) -> Bool {
        return (amiibo.lastPathComponent == self.tagStore.selected?.lastPathComponent)
    }
}
