//
//  SavedLink.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation

enum SavedContentType: String, Codable {
    case link
    case image
}

struct SavedLink: Identifiable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let excerpt: String
    let thumbnailURL: URL?
    var isRead: Bool
    var isStarred: Bool
    var isHighlighted: Bool
    var isOfflineCached: Bool
    var dateAdded: Date
    var deletedDate: Date?

    // NEW: Image-specific properties
    let contentType: SavedContentType
    let localImagePath: String?
    let imageSize: CGSize?
    let imageFormat: String?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        excerpt: String,
        thumbnailURL: URL? = nil,
        isRead: Bool = false,
        isStarred: Bool = false,
        isHighlighted: Bool = false,
        isOfflineCached: Bool = false,
        dateAdded: Date = Date(),
        deletedDate: Date? = nil,
        contentType: SavedContentType = .link,
        localImagePath: String? = nil,
        imageSize: CGSize? = nil,
        imageFormat: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.thumbnailURL = thumbnailURL
        self.isRead = isRead
        self.isStarred = isStarred
        self.isHighlighted = isHighlighted
        self.isOfflineCached = isOfflineCached
        self.dateAdded = dateAdded
        self.deletedDate = deletedDate
        self.contentType = contentType
        self.localImagePath = localImagePath
        self.imageSize = imageSize
        self.imageFormat = imageFormat
    }
}

// MARK: - Mock Data
extension SavedLink {
    static let mockLinks: [SavedLink] = [
        SavedLink(
            url: URL(string: "https://www.apple.com/newsroom/2024/01/apple-vision-pro")!,
            title: "Apple Vision Pro: A New Era of Spatial Computing",
            excerpt: "Apple today unveiled Apple Vision Pro, a revolutionary spatial computer that seamlessly blends digital content with the physical world. Vision Pro is Apple's first 3D camera, allowing users to capture magical spatial photos and videos.",
            thumbnailURL: URL(string: "https://www.apple.com/newsroom/images/product/vision-pro/standard/Apple-Vision-Pro-hero-230605_big.jpg.large.jpg"),
            isRead: false,
            isStarred: true,
            isHighlighted: true
        ),
        SavedLink(
            url: URL(string: "https://developer.apple.com/swift")!,
            title: "Swift - A Powerful and Intuitive Programming Language",
            excerpt: "Swift is a powerful and intuitive programming language for iOS, iPadOS, macOS, tvOS, and watchOS. Writing Swift code is interactive and fun, the syntax is concise yet expressive, and Swift includes modern features developers love.",
            thumbnailURL: URL(string: "https://developer.apple.com/swift/images/swift-og.png"),
            isRead: true,
            isStarred: true
        ),
        SavedLink(
            url: URL(string: "https://www.theverge.com")!,
            title: "The Future of Technology and Innovation",
            excerpt: "Exploring the latest trends in technology, from artificial intelligence to quantum computing. The landscape is changing rapidly, and companies are racing to stay ahead. This article explores what's next in the world of tech innovation.",
            thumbnailURL: nil,
            isRead: false,
            isStarred: false
        ),
        SavedLink(
            url: URL(string: "https://medium.com/design")!,
            title: "Modern Design Principles for 2024",
            excerpt: "A comprehensive guide to modern UI/UX design principles. Learn about color theory, typography, spacing, and how to create intuitive user experiences that delight users. These principles apply across platforms.",
            thumbnailURL: nil,
            isRead: true,
            isStarred: false,
            isHighlighted: true
        ),
        SavedLink(
            url: URL(string: "https://www.example.com/deleted")!,
            title: "Recently Deleted Article",
            excerpt: "This article was marked for deletion and will be permanently removed after 30 days. You can still restore it if needed before the deadline expires.",
            thumbnailURL: nil,
            isRead: true,
            isStarred: false,
            deletedDate: Date()
        )
    ]
}

// MARK: - Image Link Factory
extension SavedLink {
    static func createImageLink(
        id: UUID = UUID(),
        imagePath: String,
        title: String,
        excerpt: String? = nil,
        imageSize: CGSize,
        imageFormat: String
    ) -> SavedLink {
        return SavedLink(
            id: id,
            url: URL(string: "local://image/\(id.uuidString)")!,
            title: title,
            excerpt: excerpt ?? "Image saved on \(Date().formatted(date: .abbreviated, time: .shortened))",
            thumbnailURL: nil,
            contentType: .image,
            localImagePath: imagePath,
            imageSize: imageSize,
            imageFormat: imageFormat
        )
    }
}
