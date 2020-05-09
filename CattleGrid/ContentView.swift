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
            if (tagStore.readingAvailable) {
                MainScreen(tagStore: _tagStore)
            } else {
                Text("Either your phone doesn't have NFC, or the app's 'entitlements' aren't correctly signed")
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
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @EnvironmentObject var tagStore: TagStore

    var body: some View {
        VStack(alignment: .center) {
            if self.tagStore.lastPageWritten > 0 {
                HStack {
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
                if (tagStore.files.count > 0) {
                    List(tagStore.files, id:\.path) { file in
                        if (file.pathExtension == "bin") { // File
                            Text(file.deletingPathExtension().lastPathComponent).onTapGesture {
                                self.tagStore.load(file)
                            }
                            .foregroundColor(self.selected(file) ? .primary : .secondary)
                        } else { // Folder
                            HStack {
                                Text(file.lastPathComponent)
                                Text("")
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.systemBackground)) //'invisible' tappable target
                                Image(systemName: "chevron.right")
                            }
                            .onTapGesture { self.tagStore.load(file) }
                        }
                    }
                    .navigationBarTitle(Text(title()), displayMode: .inline)
                    .navigationBarItems(
                        leading: Button(action: {
                            self.tagStore.load(self.tagStore.currentDir.deletingLastPathComponent())
                        }) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .disabled(atDocumentsDir())
                    )
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

    func selected(_ file: URL) -> Bool {
        return (file.lastPathComponent == self.tagStore.selected?.lastPathComponent)
    }

    func atDocumentsDir() -> Bool {
        return tagStore.currentDir.standardizedFileURL == self.documents.standardizedFileURL
    }

    func title() -> String {
        if (atDocumentsDir()) {
            return "CattleGrid"
        } else {
            return self.tagStore.currentDir.lastPathComponent
        }
    }
}
