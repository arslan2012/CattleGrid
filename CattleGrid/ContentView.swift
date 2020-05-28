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
    @State private var searchText: String = ""

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
                    List(tagStore.files, id: \.path) { file in
                        ListElement(name: file.deletingPathExtension().lastPathComponent, selected: self.selected(file), isFile: (file.pathExtension == "bin"), cb: {
                            self.tagStore.load(file)
                        })
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
                                            .opacity(atDocumentsDir() ? 0 : 1)
                            )
                } else {
                    Text("No figures.").font(.headline)
                            .navigationBarTitle(Text(title()), displayMode: .inline)
                            .navigationBarItems(
                                    leading: Button(action: {
                                        self.tagStore.load(self.tagStore.currentDir.deletingLastPathComponent())
                                    }) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                            .disabled(atDocumentsDir())
                                            .opacity(atDocumentsDir() ? 0 : 1)
                            )
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
                        .frame(width: 100, height: 100)
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

    func filtered(_ urls: [URL]) -> [URL] {
        urls.filter {
            self.searchText.isEmpty ? true : $0.lastPathComponent.contains(self.searchText)
        }
    }

    func selected(_ file: URL) -> Bool {
        file.lastPathComponent == self.tagStore.selected?.lastPathComponent
    }

    func atDocumentsDir() -> Bool {
        tagStore.currentDir.standardizedFileURL == self.tagStore.documents.standardizedFileURL
    }

    func title() -> String {
        if (atDocumentsDir()) {
            return "CattleGrid"
        } else {
            return self.tagStore.currentDir.lastPathComponent
        }
    }
}

struct ListElement: View {
    let name: String
    let selected: Bool
    let isFile: Bool
    let cb: () -> Void

    var body: some View {
        HStack {
            if (isFile) {
                Text(name)
                        .foregroundColor(selected ? .primary : .secondary)
                        .onTapGesture(perform: cb)
            } else { // Folder
                HStack {
                    Text(name)
                    Text("")
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemBackground)) //'invisible' tappable target
                    Image(systemName: "chevron.right")
                }
                        .onTapGesture(perform: cb)
            }
        }
    }
}
