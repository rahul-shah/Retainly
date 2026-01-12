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

        info += "App Group: \(appGroupIdentifier)\n\n"

        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            debugInfo = "❌ Failed to access App Group UserDefaults"
            return
        }

        info += "✓ App Group UserDefaults accessible\n\n"

        // Show all keys in UserDefaults
        let allKeys = userDefaults.dictionaryRepresentation().keys.sorted()
        info += "All keys in UserDefaults (\(allKeys.count)):\n"
        for key in allKeys {
            info += "  - \(key)\n"
        }
        info += "\n"

        // Check for our specific key
        info += "Looking for key: '\(linksKey)'\n\n"

        if let data = userDefaults.data(forKey: linksKey) {
            info += "✓ Data exists (\(data.count) bytes)\n\n"

            if let links = try? JSONDecoder().decode([SavedLink].self, from: data) {
                info += "✓ Successfully decoded \(links.count) links\n\n"

                for (index, link) in links.enumerated() {
                    info += "Link \(index + 1):\n"
                    info += "  Title: \(link.title)\n"
                    info += "  URL: \(link.url.absoluteString)\n"
                    info += "  Read: \(link.isRead)\n"
                    info += "  Date: \(link.dateAdded)\n\n"
                }
            } else {
                info += "❌ Failed to decode links from data\n"
                info += "Raw data (first 100 bytes): \(String(data: data.prefix(100), encoding: .utf8) ?? "not UTF8")\n\n"
            }
        } else {
            info += "❌ No data found for key '\(linksKey)'\n\n"

            // Try standard UserDefaults as fallback
            if let standardData = UserDefaults.standard.data(forKey: linksKey) {
                info += "⚠️ WARNING: Data found in STANDARD UserDefaults instead!\n"
                info += "This means the Share Extension is saving to the wrong location.\n\n"
            }
        }

        debugInfo = info
    }

    private func addTestLink() {
        let testLink = SavedLink(
            url: URL(string: "https://www.apple.com")!,
            title: "Test Link - \(Date())",
            excerpt: "This is a test link added from debug view",
            isRead: false
        )

        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        var links: [SavedLink] = []
        if let data = userDefaults.data(forKey: linksKey),
           let decodedLinks = try? JSONDecoder().decode([SavedLink].self, from: data) {
            links = decodedLinks
        }

        links.insert(testLink, at: 0)

        if let encoded = try? JSONEncoder().encode(links) {
            userDefaults.set(encoded, forKey: linksKey)
            userDefaults.synchronize()
        }

        loadDebugInfo()
    }

    private func clearAllData() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        userDefaults.removeObject(forKey: linksKey)
        userDefaults.synchronize()

        loadDebugInfo()
    }
}

#Preview {
    DebugView()
}
