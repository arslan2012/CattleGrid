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
#if targetEnvironment(simulator)
        MainScreen(tagStore: _tagStore)
#else
        if (tagStore.readingAvailable) {
            MainScreen(tagStore: _tagStore)
        } else {
            VStack(alignment: .center) {
                Text(warning)
                    .foregroundColor(.red)
                    .font(.largeTitle)
                    .padding()
            }
        }
#endif
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
        
        NavigationView {
            GeometryReader { geometry in
                VStack() {
                                       
                    // File selector
                    Group {
                        if (tagStore.files.count > 0) {
                            List(tagStore.files, id: \.path) { file in
                                ListElement(name: file.deletingPathExtension().lastPathComponent, selected: self.selected(file), isFile: (file.pathExtension == "bin"), cb: {
                                    self.tagStore.load(file)
                                })
                            }.listStyle(PlainListStyle())
                        } else {
                            Spacer()
                            Text("No figures").font(.headline)
                            Spacer()
                        }
                    }
                    
                    // Footer
                    VStack {
                        
                        Text(self.tagStore.error)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                            .isHidden(self.tagStore.error.isEmpty)
                        
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
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                    .background(Color("BarColor"))
                }
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle(Text(title()), displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: {
                        self.tagStore.clearSelected()
                        self.tagStore.load(self.tagStore.currentDir.deletingLastPathComponent())
                    }) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                        .disabled(atDocumentsDir())
                        .opacity(atDocumentsDir() ? 0 : 1)
                )
                .onAppear(perform: self.tagStore.start)
                .onDisappear(perform: self.tagStore.stop)
                
            }
        }
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
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "checkmark").isHidden(!selected).padding(.trailing)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .onTapGesture(perform: cb)
            } else { // Folder
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .onTapGesture(perform: cb)
            }
        }
    }
}

extension View {
    /// Hide or show the view based on a boolean value.
    ///
    /// Example for visibility:
    ///
    ///     Text("Label")
    ///         .isHidden(true)
    ///
    /// Example for complete removal:
    ///
    ///     Text("Label")
    ///         .isHidden(true, remove: true)
    ///
    /// - Parameters:
    ///   - hidden: Set to `false` to show the view. Set to `true` to hide the view.
    ///   - remove: Boolean value indicating whether or not to remove the view.
    @ViewBuilder func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
}
