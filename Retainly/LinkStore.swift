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
    private let linksKey = "savedLinks"
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let migrationKey = "didMigrateToiCloud"

    @Published var links: [SavedLink] = []

    init() {
        migrateFromAppGroupIfNeeded()
        setupiCloudSync()
        loadLinks()
    }

    private func migrateFromAppGroupIfNeeded() {
        // Check if migration already happened
        if iCloudStore.bool(forKey: migrationKey) {
            print("Already migrated to iCloud")
            return
        }

        print("Attempting migration from App Group to iCloud...")

        // Try to load from old App Group storage
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let oldData = userDefaults.data(forKey: linksKey),
              let oldLinks = try? JSONDecoder().decode([SavedLink].self, from: oldData) else {
            print("No old data to migrate")
            // Mark as migrated even if there's no data
            iCloudStore.set(true, forKey: migrationKey)
            iCloudStore.synchronize()
            return
        }

        print("Found \(oldLinks.count) links in App Group storage, migrating to iCloud...")

        // Save to iCloud
        if let encoded = try? JSONEncoder().encode(oldLinks) {
            iCloudStore.set(encoded, forKey: linksKey)
            iCloudStore.set(true, forKey: migrationKey)
            iCloudStore.synchronize()
            print("Successfully migrated \(oldLinks.count) links to iCloud")

            // Optional: Clear old data from App Group
            userDefaults.removeObject(forKey: linksKey)
        } else {
            print("Failed to encode links for migration")
        }
    }

    private func setupiCloudSync() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )

        // Sync with iCloud
        iCloudStore.synchronize()
    }

    @objc private func iCloudStoreDidChange(notification: Notification) {
        print("iCloud store changed externally, reloading links")
        DispatchQueue.main.async {
            self.loadLinks()
        }
    }

    func loadLinks() {
        print("📥 Loading links from iCloud...")

        // Force synchronize with iCloud before reading
        let syncResult = iCloudStore.synchronize()
        print("iCloud sync result: \(syncResult)")

        guard let data = iCloudStore.data(forKey: linksKey) else {
            links = []
            print("LinkStore: No data found in iCloud, starting with empty array")
            return
        }

        do {
            let loadedLinks = try JSONDecoder().decode([SavedLink].self, from: data)
            links = loadedLinks
            print("✅ LinkStore: Loaded \(links.count) links from iCloud")
        } catch {
            print("❌ Error loading links from iCloud: \(error)")
            links = []
        }
    }

    func saveLinks() {
        do {
            let data = try JSONEncoder().encode(links)
            iCloudStore.set(data, forKey: linksKey)
            let syncResult = iCloudStore.synchronize()
            print("💾 LinkStore: Saved \(links.count) links to iCloud (sync: \(syncResult))")

            // Debug: Print starred links
            let starredCount = links.filter { $0.isStarred && $0.deletedDate == nil }.count
            print("   ⭐ Starred links: \(starredCount)")
        } catch {
            print("❌ Error saving links to iCloud: \(error)")
        }
    }

    func addLink(_ link: SavedLink) {
        links.insert(link, at: 0)
        saveLinks()
    }

    func updateLink(_ link: SavedLink) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            let oldLink = links[index]
            links[index] = link
            saveLinks()
            print("📝 LinkStore: Updated link '\(link.title)'")
            print("   - isStarred: \(oldLink.isStarred) → \(link.isStarred)")
            print("   - isRead: \(oldLink.isRead) → \(link.isRead)")
        } else {
            print("⚠️ LinkStore: Could not find link to update (ID: \(link.id))")
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
