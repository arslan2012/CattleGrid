//
//  ContentView.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/10/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import SwiftUI
import CachedAsyncImage

struct ContentView: View {
    @EnvironmentObject var tagStore: TagStore
    
    @State private var searchText = ""
    
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
    @State private var imageUrl: String = ""
    
    let columns = [
        GridItem(.fixed(200)),
        GridItem(.fixed(200)),
    ]
    
    var body: some View {
        
        NavigationView {
            GeometryReader { geometry in
                VStack() {
                    
                    // File selector
                    Group {
                        if (tagStore.contents.count > 0) {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing:20) {
                                    ForEach(searchResults, id: \.url) { content in
                                        ListElement(content: content, selected: content.isSelected, isFile: content.isFile, cb: {
                                            
                                            if content.isFile {
                                                content.isSelected = true
                                                self.tagStore.setSelected(content: content)
                                            }
                                            
                                            self.tagStore.load(content.url)
                                            
                                            if let characterImageFilename = content.characterImageFilename {
                                                imageUrl = "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/\(characterImageFilename)"
                                            }
                                        })
                                    }
                                }
                                .searchable(text: $searchText)
                            }
                            //                            List(searchResults, id: \.url) { content in
                            //                                ListElement(name: content.filenameWithoutExtension, selected: content.isSelected, isFile: content.isFile, cb: {
                            //
                            //                                    if content.isFile {
                            //                                        content.isSelected = true
                            //                                        self.tagStore.setSelected(content: content)
                            //                                    }
                            //
                            //                                    self.tagStore.load(content.url)
                            //
                            //                                    if let characterImageFilename = content.characterImageFilename {
                            //                                        imageUrl = "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/\(characterImageFilename)"
                            //                                    }
                            //                                })
                            //                            }
                            //                            .listStyle(PlainListStyle())
                            //                            .searchable(text: $searchText)
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
                        HStack {
                            //button to say 'go'
                            Button(action: self.tagStore.scan) {
                                Image(systemName: "arrow.down.doc")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .disabled(!self.tagStore.hasSelection())
                                    .padding()
                            }
                            .disabled(!self.tagStore.hasSelection())
                        }
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
    
    var searchResults: [FileManagerContent] {
        if searchText.isEmpty {
            return tagStore.contents
        } else {
            return tagStore.contents.filter { $0.url.absoluteString.contains(searchText) }
        }
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
    let content: FileManagerContent
    let selected: Bool
    let isFile: Bool
    let cb: () -> Void
    
    var body: some View {
        if (isFile) {
            VStack {
                CachedAsyncImage(url: content.characterImageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                } placeholder: {
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .frame(maxWidth: 150, maxHeight: 150)
                }
                
                Text(content.filenameWithoutExtension)
                
                Spacer()
            }
            .padding()
            .if(selected) {
                $0.border(Color.blue, width: 4)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: 200)
            .onTapGesture(perform: cb)
        } else { // Folder
            VStack {
                Image(systemName: "folder")
                    .resizable()
                    .frame(width: 100, height: 100)
                
                Text(content.filenameWithoutExtension)
                
            }
            .padding()
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
            .onTapGesture(perform: cb)
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
    
    func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> TupleView<(Self?, Content?)> {
        if conditional {
            return TupleView((nil, content(self)))
        } else {
            return TupleView((self, nil))
        }
    }
}
