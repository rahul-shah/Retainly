//
//  LinkRowView.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI

struct LinkRowView: View {
    let link: SavedLink

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(link.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(link.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)

                HStack(spacing: 12) {
                    if link.contentType == .image {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("Image")
                        }
                        .font(.caption)
                        .foregroundStyle(.purple)
                    }

                    if link.isStarred {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("Starred")
                        }
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    }

                    if link.isHighlighted {
                        HStack(spacing: 4) {
                            Image(systemName: "highlighter")
                            Text("Highlighted")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }

                    if link.isOfflineCached {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Offline")
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    }

                    Spacer()

                    Text(link.dateAdded, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch link.contentType {
        case .image:
            // Load local image from App Group storage
            if let imagePath = link.localImagePath,
               let thumbnailURL = getLocalImageURL(imagePath) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.1))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage(systemName: "photo.fill")
                    @unknown default:
                        placeholderImage(systemName: "photo.fill")
                    }
                }
            } else {
                placeholderImage(systemName: "photo.fill")
            }

        case .link:
            // Load remote thumbnail URL for links
            if let thumbnailURL = link.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.1))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage(systemName: "link.circle.fill")
                    @unknown default:
                        placeholderImage(systemName: "link.circle.fill")
                    }
                }
            } else {
                placeholderImage(systemName: "link.circle.fill")
            }
        }
    }

    private func getLocalImageURL(_ imagePath: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.rahul.retainly"
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent(imagePath)
    }

    private func placeholderImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.largeTitle)
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    List {
        ForEach(SavedLink.mockLinks) { link in
            LinkRowView(link: link)
        }
    }
}
