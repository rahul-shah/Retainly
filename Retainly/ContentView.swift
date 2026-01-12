//
//  ContentView.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedCategory: SidebarCategory? = .unread
    @StateObject private var linkStore = LinkStore()
    @State private var showDebug = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section {
                    ForEach(SidebarCategory.allCases) { category in
                        NavigationLink(value: category) {
                            HStack {
                                Label(category.rawValue, systemImage: category.icon)
                                Spacer()
                                let count = linkStore.count(for: category)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(category == .unread ? Color.blue : Color.secondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Section("Debug") {
                    Button {
                        showDebug = true
                    } label: {
                        Label("Debug Info", systemImage: "ladybug")
                    }
                }
            }
            .navigationTitle("Retainly")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            #endif
        } detail: {
            if let selectedCategory {
                CategoryDetailView(category: selectedCategory, linkStore: linkStore)
            } else {
                Text("Select a category")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showDebug) {
            NavigationStack {
                DebugView()
                    .navigationTitle("Debug")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showDebug = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            linkStore.loadLinks()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                linkStore.loadLinks()
            }
        }
    }
}

#Preview {
    ContentView()
}
