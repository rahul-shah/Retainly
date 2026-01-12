//
//  LinkMetadataFetcher.swift
//  RetainlyShareExtension
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation
import LinkPresentation

class LinkMetadataFetcher {
    static func fetchMetadata(for url: URL) async throws -> (title: String, excerpt: String, thumbnailURL: URL?) {
        let provider = LPMetadataProvider()

        let metadata = try await provider.startFetchingMetadata(for: url)

        let title = metadata.title ?? url.host ?? "Untitled"

        // Try to get excerpt from metadata
        var excerpt = ""
        if let summary = metadata.value(forKey: "summary") as? String, !summary.isEmpty {
            excerpt = summary
        } else {
            excerpt = "Saved from \(url.host ?? "web")"
        }

        // Get thumbnail URL if available
        var thumbnailURL: URL? = nil

        // Try to get image URL from metadata
        if let imageProvider = metadata.imageProvider {
            // We have an image, but LPMetadataProvider doesn't directly expose the URL
            // We'll need to load the image and potentially upload/cache it
            // For now, try to extract from iconProvider or remoteVideoURL
            if let iconProvider = metadata.iconProvider {
                // Icon provider exists but we need the actual URL
            }

            // Try to get from the URL itself using Open Graph parsing
            thumbnailURL = try? await extractThumbnailFromHTML(url: url)
        }

        return (title, excerpt, thumbnailURL)
    }

    private static func extractThumbnailFromHTML(url: URL) async throws -> URL? {
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Look for Open Graph image
        if let ogImageURL = extractMetaTag(from: html, property: "og:image") {
            return URL(string: ogImageURL)
        }

        // Look for Twitter card image
        if let twitterImageURL = extractMetaTag(from: html, property: "twitter:image") {
            return URL(string: twitterImageURL)
        }

        // Look for article:image
        if let articleImageURL = extractMetaTag(from: html, property: "article:image") {
            return URL(string: articleImageURL)
        }

        return nil
    }

    private static func extractMetaTag(from html: String, property: String) -> String? {
        // Look for meta tag with property
        let propertyPattern = "<meta\\s+property=\"\(property)\"\\s+content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: propertyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }

        // Look for meta tag with name
        let namePattern = "<meta\\s+name=\"\(property)\"\\s+content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: namePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }

        // Try reversed order (content before property/name)
        let reversedPattern = "<meta\\s+content=\"([^\"]+)\"\\s+(?:property|name)=\"\(property)\""
        if let regex = try? NSRegularExpression(pattern: reversedPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }

        return nil
    }
}
