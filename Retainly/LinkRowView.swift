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
                    if link.isStarred {
                        Label("Starred", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    if link.isHighlighted {
                        Label("Highlighted", systemImage: "highlighter")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if link.isOfflineCached {
                        Label("Offline", systemImage: "arrow.down.circle.fill")
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
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "link.circle.fill")
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
