//
//  OfflineContentManager.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation
import WebKit

struct OfflineMetadata: Codable {
    let fileURL: String
    let savedDate: TimeInterval
}

actor OfflineContentManager {
    static let shared = OfflineContentManager()

    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let offlineContentKey = "offlineContent"
    private let iCloudStore = NSUbiquitousKeyValueStore.default

    private init() {}

    func saveContent(for link: SavedLink) async {
        print("Saving offline content for: \(link.url)")

        do {
            // Fetch the HTML content
            let (data, response) = try await URLSession.shared.data(from: link.url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Failed to fetch content: Invalid response")
                return
            }

            // Save to App Group shared container
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            ) else {
                print("Failed to access App Group container")
                return
            }

            let offlineFolder = containerURL.appendingPathComponent("OfflineContent", isDirectory: true)

            // Create offline content directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: offlineFolder.path) {
                try FileManager.default.createDirectory(at: offlineFolder, withIntermediateDirectories: true)
            }

            // Use link ID as filename
            let fileName = link.id.uuidString + ".html"
            let fileURL = offlineFolder.appendingPathComponent(fileName)

            // Save HTML content
            try data.write(to: fileURL)

            // Update metadata
            await saveOfflineMetadata(linkId: link.id, fileURL: fileURL)

            print("Successfully saved offline content to: \(fileURL.path)")
        } catch {
            print("Error saving offline content: \(error.localizedDescription)")
        }
    }

    func getOfflineContent(for linkId: UUID) async -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let offlineFolder = containerURL.appendingPathComponent("OfflineContent", isDirectory: true)
        let fileName = linkId.uuidString + ".html"
        let fileURL = offlineFolder.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        return nil
    }

    func hasOfflineContent(for linkId: UUID) async -> Bool {
        await getOfflineContent(for: linkId) != nil
    }

    func deleteOfflineContent(for linkId: UUID) async {
        guard let fileURL = await getOfflineContent(for: linkId) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            print("Deleted offline content for link: \(linkId)")
        } catch {
            print("Error deleting offline content: \(error.localizedDescription)")
        }
    }

    private func saveOfflineMetadata(linkId: UUID, fileURL: URL) async {
        var metadata = loadOfflineMetadata()
        metadata[linkId.uuidString] = OfflineMetadata(
            fileURL: fileURL.path,
            savedDate: Date().timeIntervalSince1970
        )

        if let encoded = try? JSONEncoder().encode(metadata) {
            iCloudStore.set(encoded, forKey: offlineContentKey)
            iCloudStore.synchronize()
        }
    }

    private func loadOfflineMetadata() -> [String: OfflineMetadata] {
        guard let data = iCloudStore.data(forKey: offlineContentKey),
              let metadata = try? JSONDecoder().decode([String: OfflineMetadata].self, from: data) else {
            return [:]
        }

        return metadata
    }
}
