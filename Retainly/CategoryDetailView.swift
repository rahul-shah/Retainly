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
                        LinkRowView(link: link)
                            .listRowSeparator(.visible)
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
