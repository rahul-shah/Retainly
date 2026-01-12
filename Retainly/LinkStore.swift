//
//  LinkStore.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation
import SwiftUI
import Combine

class LinkStore: ObservableObject {
    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let linksKey = "savedLinks"

    @Published var links: [SavedLink] = []

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    init() {
        loadLinks()
    }

    func loadLinks() {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: linksKey) else {
            links = []
            print("LinkStore: No data found, starting with empty array")
            return
        }

        do {
            let loadedLinks = try JSONDecoder().decode([SavedLink].self, from: data)
            links = loadedLinks
            print("LinkStore: Loaded \(links.count) links")
        } catch {
            print("Error loading links: \(error)")
            links = []
        }
    }

    func saveLinks() {
        guard let userDefaults = userDefaults else { return }

        do {
            let data = try JSONEncoder().encode(links)
            userDefaults.set(data, forKey: linksKey)
        } catch {
            print("Error saving links: \(error)")
        }
    }

    func addLink(_ link: SavedLink) {
        links.insert(link, at: 0)
        saveLinks()
    }

    func updateLink(_ link: SavedLink) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links[index] = link
            saveLinks()
        }
    }

    func deleteLink(_ link: SavedLink) {
        var updatedLink = link
        updatedLink.deletedDate = Date()
        updateLink(updatedLink)
    }

    func permanentlyDeleteLink(_ link: SavedLink) {
        links.removeAll { $0.id == link.id }
        saveLinks()
    }

    func filteredLinks(for category: SidebarCategory) -> [SavedLink] {
        switch category {
        case .unread:
            return links.filter { !$0.isRead && $0.deletedDate == nil }
        case .read:
            return links.filter { $0.isRead && $0.deletedDate == nil }
        case .starred:
            return links.filter { $0.isStarred && $0.deletedDate == nil }
        case .highlighted:
            return links.filter { $0.isHighlighted && $0.deletedDate == nil }
        case .all:
            return links.filter { $0.deletedDate == nil }
        case .recentlyDeleted:
            return links.filter { $0.deletedDate != nil }
        }
    }

    func count(for category: SidebarCategory) -> Int {
        filteredLinks(for: category).count
    }
}
