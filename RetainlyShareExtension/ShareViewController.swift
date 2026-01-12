//
//  ShareViewController.swift
//  RetainlyShareExtension
//
//  Created by Rahul Shah on 12/01/2026.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let linksKey = "savedLinks"

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "Saving to Retainly..."
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        handleSharedContent()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("No content to share")
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil, completionHandler: { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    print("Error loading item: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.showError("Error: \(error.localizedDescription)")
                    }
                    return
                }

                var urlToSave: URL?

                if let url = item as? URL {
                    urlToSave = url
                    print("Extracted URL directly: \(url)")
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urlToSave = url
                    print("Extracted URL from data: \(url)")
                } else if let urlString = item as? String, let url = URL(string: urlString) {
                    urlToSave = url
                    print("Extracted URL from string: \(url)")
                } else {
                    print("Failed to extract URL. Item type: \(type(of: item))")
                }

                if let url = urlToSave {
                    Task {
                        await self.fetchMetadataAndSave(url: url)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showError("Could not extract URL")
                    }
                }
            })
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil, completionHandler: { [weak self] (item, error) in
                guard let self = self else { return }

                if let urlString = item as? String, let url = URL(string: urlString) {
                    print("Extracted URL from text: \(url)")
                    Task {
                        await self.fetchMetadataAndSave(url: url)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showError("Could not extract URL from text")
                    }
                }
            })
        } else {
            showError("Please share a web page or URL")
        }
    }

    private func fetchMetadataAndSave(url: URL) async {
        // Update UI to show fetching status
        await MainActor.run {
            messageLabel.text = "Fetching article details..."
        }

        // Fetch metadata
        var title = url.host ?? "Saved Link"
        var excerpt = "Link saved from Safari. Tap to view more details."
        var thumbnailURL: URL? = nil

        do {
            let metadata = try await LinkMetadataFetcher.fetchMetadata(for: url)
            title = metadata.title
            excerpt = metadata.excerpt
            thumbnailURL = metadata.thumbnailURL

            print("Fetched metadata - Title: \(title)")
            if let thumb = thumbnailURL {
                print("Thumbnail URL: \(thumb)")
            }
        } catch {
            print("Failed to fetch metadata: \(error.localizedDescription)")
            // Continue with basic info
        }

        // Create link with fetched metadata
        let link = SavedLink(
            url: url,
            title: title,
            excerpt: excerpt,
            thumbnailURL: thumbnailURL,
            isRead: false
        )

        // Save to UserDefaults
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Failed to access App Group: \(appGroupIdentifier)")
            await MainActor.run {
                showError("Failed to save")
            }
            return
        }

        var links: [SavedLink] = []
        if let data = userDefaults.data(forKey: linksKey),
           let decodedLinks = try? JSONDecoder().decode([SavedLink].self, from: data) {
            links = decodedLinks
            print("Loaded \(links.count) existing links")
        }

        links.insert(link, at: 0)

        if let encoded = try? JSONEncoder().encode(links) {
            userDefaults.set(encoded, forKey: linksKey)
            userDefaults.synchronize()
            print("Link saved successfully: \(url)")
            print("Total links: \(links.count)")

            await MainActor.run {
                showSuccess()
            }
        } else {
            print("Failed to encode links")
            await MainActor.run {
                showError("Failed to save")
            }
        }
    }

    private func showSuccess() {
        messageLabel.text = "✓ Saved to Retainly"
        messageLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.closeExtension()
        }
    }

    private func showError(_ message: String) {
        messageLabel.text = message
        messageLabel.textColor = .systemRed

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.closeExtension()
        }
    }

    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
