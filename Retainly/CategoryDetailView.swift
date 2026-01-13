//
//  CategoryDetailView.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI

struct CategoryDetailView: View {
    let category: SidebarCategory
    @ObservedObject var linkStore: LinkStore
    @State private var selectedLink: SavedLink?

    var filteredLinks: [SavedLink] {
        linkStore.filteredLinks(for: category)
    }

    var body: some View {
        Group {
            if filteredLinks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredLinks) { link in
                        Button {
                            selectedLink = link
                        } label: {
                            LinkRowView(link: link)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.visible)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if category == .recentlyDeleted {
                                Button(role: .destructive) {
                                    linkStore.permanentlyDeleteLink(link)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }

                                Button {
                                    restoreLink(link)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            } else {
                                Button(role: .destructive) {
                                    linkStore.deleteLink(link)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            linkStore.loadLinks()
        }
        .sheet(item: $selectedLink) { link in
            WebViewContainer(link: link, linkStore: linkStore)
        }
    }

    private func restoreLink(_ link: SavedLink) {
        var restoredLink = link
        restoredLink.deletedDate = nil
        linkStore.updateLink(restoredLink)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("No \(category.rawValue) Links")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Links you save will appear here")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: .unread, linkStore: LinkStore())
    }
}
