//
//  ShareViewController.swift
//  RetainlyShareExtension
//
//  Created by Rahul Shah on 12/01/2026.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

enum SharedContentType {
    case url(URL)
    case image(Data, fileName: String)
    case imageURL(URL)
}

class ShareViewController: UIViewController {
    private let linksKey = "savedLinks"
    private let iCloudStore = NSUbiquitousKeyValueStore.default

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

        Task {
            await detectAndHandleContent(itemProvider: itemProvider)
        }
    }

    private func detectAndHandleContent(itemProvider: NSItemProvider) async {
        // Priority: image > URL > text
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            await handleImageContent(itemProvider: itemProvider)
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            await handleURLContent(itemProvider: itemProvider)
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            await handleTextContent(itemProvider: itemProvider)
        } else {
            await MainActor.run {
                showError("Unsupported content type")
            }
        }
    }

    private func handleImageContent(itemProvider: NSItemProvider) async {
        await MainActor.run {
            messageLabel.text = "Loading image..."
        }

        guard let imageData = await loadImageData(from: itemProvider) else {
            await MainActor.run {
                showError("Failed to load image")
            }
            return
        }

        await saveImageToRetainly(imageData: imageData.data, fileName: imageData.fileName)
    }

    private func handleURLContent(itemProvider: NSItemProvider) async {
        guard let url = await loadURL(from: itemProvider) else {
            await MainActor.run {
                showError("Could not extract URL")
            }
            return
        }

        // Check if URL is an image URL
        if isImageURL(url) {
            await downloadAndSaveImage(from: url)
        } else {
            await fetchMetadataAndSave(url: url)
        }
    }

    private func handleTextContent(itemProvider: NSItemProvider) async {
        guard let url = await loadURLFromText(from: itemProvider) else {
            await MainActor.run {
                showError("Could not extract URL from text")
            }
            return
        }

        if isImageURL(url) {
            await downloadAndSaveImage(from: url)
        } else {
            await fetchMetadataAndSave(url: url)
        }
    }

    private func loadImageData(from itemProvider: NSItemProvider) async -> (data: Data, fileName: String)? {
        return await withCheckedContinuation { continuation in
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error = error {
                    print("Error loading image: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                if let url = item as? URL {
                    // Image file URL (Photos app, Files app)
                    if let data = try? Data(contentsOf: url) {
                        let fileName = url.lastPathComponent
                        continuation.resume(returning: (data, fileName))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else if let data = item as? Data {
                    // Direct image data
                    continuation.resume(returning: (data, "image.jpg"))
                } else if let image = item as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.9) {
                    // UIImage object
                    continuation.resume(returning: (data, "image.jpg"))
                } else {
                    print("Unknown image item type: \(type(of: item))")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadURL(from itemProvider: NSItemProvider) async -> URL? {
        return await withCheckedContinuation { continuation in
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    print("Error loading URL: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let urlString = item as? String, let url = URL(string: urlString) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadURLFromText(from itemProvider: NSItemProvider) async -> URL? {
        return await withCheckedContinuation { continuation in
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                if let urlString = item as? String, let url = URL(string: urlString) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func isImageURL(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"]
        let pathExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(pathExtension)
    }

    private func downloadAndSaveImage(from url: URL) async {
        await MainActor.run {
            messageLabel.text = "Downloading image..."
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    showError("Failed to download image")
                }
                return
            }

            let fileName = url.lastPathComponent
            await saveImageToRetainly(imageData: data, fileName: fileName)
        } catch {
            print("Error downloading image: \(error)")
            await MainActor.run {
                showError("Failed to download image")
            }
        }
    }

    private func saveImageToRetainly(imageData: Data, fileName: String) async {
        await MainActor.run {
            messageLabel.text = "Saving image..."
        }

        let linkId = UUID()
        let format = ImageFormat.detect(from: imageData)

        do {
            // Save image using ImageStorageManager
            let metadata = try await ImageStorageManager.shared.saveImage(imageData, for: linkId, format: format)

            // Extract title from filename
            let title = (fileName as NSString).deletingPathExtension
            let cleanTitle = title.isEmpty ? "Saved Image" : title

            // Create SavedLink for the image
            let link = SavedLink.createImageLink(
                id: linkId,
                imagePath: metadata.originalPath,
                title: cleanTitle,
                imageSize: metadata.size,
                imageFormat: metadata.format
            )

            // Save to iCloud
            await saveLink(link)
        } catch {
            print("Error saving image: \(error)")
            await MainActor.run {
                showError("Failed to save image")
            }
        }
    }

    private func saveLink(_ link: SavedLink) async {
        print("📱 Saving link to iCloud...")

        // Force synchronize before reading
        let syncResult = iCloudStore.synchronize()
        print("iCloud sync before read: \(syncResult)")

        var links: [SavedLink] = []
        if let data = iCloudStore.data(forKey: linksKey) {
            do {
                links = try JSONDecoder().decode([SavedLink].self, from: data)
                print("✓ Loaded \(links.count) existing links")
            } catch {
                print("❌ Failed to decode links: \(error)")
            }
        }

        links.insert(link, at: 0)

        do {
            let encoded = try JSONEncoder().encode(links)
            iCloudStore.set(encoded, forKey: linksKey)
            iCloudStore.synchronize()

            print("✅ Saved successfully to iCloud")

            await MainActor.run {
                showSuccess()
            }
        } catch {
            print("❌ Failed to save: \(error)")
            await MainActor.run {
                showError("Failed to save")
            }
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

        // Save to iCloud using shared method
        await saveLink(link)
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
