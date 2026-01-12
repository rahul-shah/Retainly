//
//  DebugView.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI

struct DebugView: View {
    @State private var debugInfo: String = "Loading..."
    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let linksKey = "savedLinks"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Debug Information")
                    .font(.title)
                    .fontWeight(.bold)

                Button("Refresh Debug Info") {
                    loadDebugInfo()
                }
                .buttonStyle(.borderedProminent)

                Text(debugInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Add Test Link") {
                    addTestLink()
                }
                .buttonStyle(.bordered)

                Button("Clear All Data") {
                    clearAllData()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
            }
            .padding()
        }
        .onAppear {
            loadDebugInfo()
        }
    }

    private func loadDebugInfo() {
        var info = ""

        info += "=== STORAGE LOCATIONS ===\n\n"

        // Check iCloud
        info += "📱 iCloud Key-Value Store:\n"
        let iCloudStore = NSUbiquitousKeyValueStore.default

        // Force sync
        let syncResult = iCloudStore.synchronize()
        info += "Sync result: \(syncResult)\n"

        // Check all keys in iCloud
        let allDictionary = iCloudStore.dictionaryRepresentation
        info += "Total keys in iCloud: \(allDictionary.keys.count)\n"
        info += "Keys: \(allDictionary.keys.sorted().joined(separator: ", "))\n\n"

        if let iCloudData = iCloudStore.data(forKey: linksKey) {
            info += "✓ iCloud data exists (\(iCloudData.count) bytes)\n"

            if let links = try? JSONDecoder().decode([SavedLink].self, from: iCloudData) {
                info += "✓ Successfully decoded \(links.count) links from iCloud\n\n"

                for (index, link) in links.prefix(5).enumerated() {
                    info += "Link \(index + 1):\n"
                    info += "  Title: \(link.title)\n"
                    info += "  URL: \(link.url.absoluteString)\n"
                    info += "  Read: \(link.isRead)\n"
                    info += "  Offline: \(link.isOfflineCached)\n\n"
                }

                if links.count > 5 {
                    info += "... and \(links.count - 5) more links\n\n"
                }
            } else {
                info += "❌ Failed to decode links from iCloud data\n\n"
            }
        } else {
            info += "❌ No data in iCloud for key '\(linksKey)'\n\n"
        }

        // Check App Group (old storage)
        info += "📦 App Group (Legacy):\n"
        info += "Identifier: \(appGroupIdentifier)\n"

        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            info += "✓ App Group accessible\n"

            if let appGroupData = userDefaults.data(forKey: linksKey) {
                info += "✓ Old data still exists (\(appGroupData.count) bytes)\n"

                if let links = try? JSONDecoder().decode([SavedLink].self, from: appGroupData) {
                    info += "✓ \(links.count) links in old storage (should be migrated)\n\n"
                }
            } else {
                info += "✓ No old data (already migrated)\n\n"
            }
        } else {
            info += "❌ Cannot access App Group\n\n"
        }

        // Migration status
        let didMigrate = iCloudStore.bool(forKey: "didMigrateToiCloud")
        info += "Migration Status: \(didMigrate ? "✓ Completed" : "⚠️ Not yet migrated")\n"

        debugInfo = info
    }

    private func addTestLink() {
        let testLink = SavedLink(
            url: URL(string: "https://www.apple.com")!,
            title: "Test Link - \(Date())",
            excerpt: "This is a test link added from debug view",
            isRead: false
        )

        let iCloudStore = NSUbiquitousKeyValueStore.default
        var links: [SavedLink] = []

        if let data = iCloudStore.data(forKey: linksKey),
           let decodedLinks = try? JSONDecoder().decode([SavedLink].self, from: data) {
            links = decodedLinks
        }

        links.insert(testLink, at: 0)

        if let encoded = try? JSONEncoder().encode(links) {
            iCloudStore.set(encoded, forKey: linksKey)
            iCloudStore.synchronize()
        }

        loadDebugInfo()
    }

    private func clearAllData() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        iCloudStore.removeObject(forKey: linksKey)
        iCloudStore.synchronize()

        // Also clear old App Group data
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.removeObject(forKey: linksKey)
            userDefaults.synchronize()
        }

        loadDebugInfo()
    }
}

#Preview {
    DebugView()
}
