//
//  ImageStorageManager.swift
//  Retainly
//
//  Created by Rahul Shah on 13/01/2026.
//

import Foundation
import UIKit

struct ImageMetadata {
    let originalPath: String
    let thumbnailPath: String
    let size: CGSize
    let format: String
    let fileSize: Int64
}

enum ImageFormat: String {
    case jpeg = "jpg"
    case png = "png"
    case heic = "heic"

    static func detect(from data: Data) -> ImageFormat {
        guard data.count >= 12 else { return .jpeg }

        let bytes = [UInt8](data.prefix(12))

        // PNG signature
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }

        // JPEG signature
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }

        // HEIC signature (simplified check)
        if bytes.count >= 12 {
            let brandBytes = Array(bytes[8..<12])
            if brandBytes == [0x68, 0x65, 0x69, 0x63] { // "heic"
                return .heic
            }
        }

        return .jpeg // default
    }

    static func detect(from fileName: String) -> ImageFormat {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return .png
        case "heic", "heif": return .heic
        default: return .jpeg
        }
    }
}

enum ImageStorageError: LocalizedError {
    case invalidData
    case compressionFailed
    case thumbnailGenerationFailed
    case saveFailed
    case containerNotFound

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid image data"
        case .compressionFailed: return "Failed to compress image"
        case .thumbnailGenerationFailed: return "Failed to generate thumbnail"
        case .saveFailed: return "Failed to save image to storage"
        case .containerNotFound: return "App Group container not found"
        }
    }
}

actor ImageStorageManager {
    static let shared = ImageStorageManager()

    private let appGroupIdentifier = "group.com.rahul.retainly"
    private let imagesFolder = "Images"
    private let maxImageDimension: CGFloat = 2048
    private let thumbnailSize: CGFloat = 80
    private let originalQuality: CGFloat = 0.8
    private let thumbnailQuality: CGFloat = 0.7

    private init() {}

    // MARK: - Public Methods

    func saveImage(_ imageData: Data, for linkId: UUID, format: ImageFormat) async throws -> ImageMetadata {
        print("💾 ImageStorage: Saving image for link ID: \(linkId)")

        guard let image = UIImage(data: imageData) else {
            throw ImageStorageError.invalidData
        }

        // Get images directory
        guard let imagesDir = getImagesDirectory() else {
            throw ImageStorageError.containerNotFound
        }

        // Compress original if needed
        let processedImage = compressImageIfNeeded(image)
        let format = determineOptimalFormat(for: processedImage, requestedFormat: format)

        // Generate file paths
        let originalFileName = "\(linkId.uuidString)_original.\(format.rawValue)"
        let thumbnailFileName = "\(linkId.uuidString)_thumbnail.jpg"

        let originalURL = imagesDir.appendingPathComponent(originalFileName)
        let thumbnailURL = imagesDir.appendingPathComponent(thumbnailFileName)

        // Save original
        guard let originalData = imageData(for: processedImage, format: format, quality: originalQuality) else {
            throw ImageStorageError.compressionFailed
        }

        try originalData.write(to: originalURL)

        // Generate and save thumbnail
        guard let thumbnail = generateThumbnail(from: processedImage, size: thumbnailSize),
              let thumbnailData = thumbnail.jpegData(compressionQuality: thumbnailQuality) else {
            throw ImageStorageError.thumbnailGenerationFailed
        }

        try thumbnailData.write(to: thumbnailURL)

        let fileSize = Int64(originalData.count)

        print("✅ ImageStorage: Saved image \(originalFileName) (\(fileSize) bytes)")

        return ImageMetadata(
            originalPath: "\(imagesFolder)/\(originalFileName)",
            thumbnailPath: "\(imagesFolder)/\(thumbnailFileName)",
            size: processedImage.size,
            format: format.rawValue,
            fileSize: fileSize
        )
    }

    func getImageURL(for linkId: UUID, thumbnail: Bool) async -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let imagesDir = containerURL.appendingPathComponent(imagesFolder)
        let suffix = thumbnail ? "thumbnail.jpg" : "original"

        // Try common formats
        let formats = ["jpg", "png", "heic"]
        for format in formats {
            let fileName = thumbnail ? "\(linkId.uuidString)_thumbnail.jpg" : "\(linkId.uuidString)_original.\(format)"
            let fileURL = imagesDir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        return nil
    }

    func deleteImage(for linkId: UUID) async throws {
        guard let imagesDir = getImagesDirectory() else {
            throw ImageStorageError.containerNotFound
        }

        // Delete all files for this link (original + thumbnail, all formats)
        let formats = ["jpg", "png", "heic"]
        var deletedCount = 0

        for format in formats {
            let originalFile = imagesDir.appendingPathComponent("\(linkId.uuidString)_original.\(format)")
            if FileManager.default.fileExists(atPath: originalFile.path) {
                try? FileManager.default.removeItem(at: originalFile)
                deletedCount += 1
            }
        }

        let thumbnailFile = imagesDir.appendingPathComponent("\(linkId.uuidString)_thumbnail.jpg")
        if FileManager.default.fileExists(atPath: thumbnailFile.path) {
            try? FileManager.default.removeItem(at: thumbnailFile)
            deletedCount += 1
        }

        print("🗑️ ImageStorage: Deleted \(deletedCount) files for link ID: \(linkId)")
    }

    func getTotalStorageSize() async -> Int64 {
        guard let imagesDir = getImagesDirectory() else {
            return 0
        }

        guard let enumerator = FileManager.default.enumerator(
            at: imagesDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    // MARK: - Private Helper Methods

    private func getImagesDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let imagesDir = containerURL.appendingPathComponent(imagesFolder)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            try? FileManager.default.createDirectory(
                at: imagesDir,
                withIntermediateDirectories: true
            )
        }

        return imagesDir
    }

    private func compressImageIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size

        // Check if image needs compression
        if size.width <= maxImageDimension && size.height <= maxImageDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxImageDimension / size.width, maxImageDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func generateThumbnail(from image: UIImage, size: CGFloat) -> UIImage? {
        let targetSize = CGSize(width: size, height: size)

        // Calculate crop rect (aspect fill)
        let imageSize = image.size
        let ratio = max(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)

        let cropOrigin = CGPoint(
            x: (scaledSize.width - targetSize.width) / 2,
            y: (scaledSize.height - targetSize.height) / 2
        )

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        let drawRect = CGRect(
            x: -cropOrigin.x,
            y: -cropOrigin.y,
            width: scaledSize.width,
            height: scaledSize.height
        )

        image.draw(in: drawRect)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func determineOptimalFormat(for image: UIImage, requestedFormat: ImageFormat) -> ImageFormat {
        // HEIC → JPEG for compatibility
        if requestedFormat == .heic {
            return .jpeg
        }

        // Check if PNG has transparency
        if requestedFormat == .png {
            if let cgImage = image.cgImage {
                let alphaInfo = cgImage.alphaInfo
                if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
                    // No transparency, convert to JPEG
                    return .jpeg
                }
            }
            return .png // Keep PNG if it has transparency
        }

        return .jpeg
    }

    private func imageData(for image: UIImage, format: ImageFormat, quality: CGFloat) -> Data? {
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: quality)
        case .png:
            return image.pngData()
        case .heic:
            // Fallback to JPEG
            return image.jpegData(compressionQuality: quality)
        }
    }
}
