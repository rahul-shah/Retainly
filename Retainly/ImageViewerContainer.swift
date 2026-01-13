//
//  ImageViewerContainer.swift
//  Retainly
//
//  Created by Rahul Shah on 13/01/2026.
//

import SwiftUI
import PhotosUI

struct ImageViewerContainer: View {
    let link: SavedLink
    @ObservedObject var linkStore: LinkStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isStarred = false

    // Zoom state
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    private var currentLink: SavedLink? {
        linkStore.links.first(where: { $0.id == link.id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if let error = loadError {
                    errorView
                } else if let image = image {
                    ZoomableImageView(
                        image: image,
                        currentScale: $currentScale,
                        finalScale: $finalScale,
                        currentOffset: $currentOffset,
                        finalOffset: $finalOffset
                    )
                } else {
                    Text("Unable to load image")
                        .foregroundColor(.white)
                }

                // Floating action bar
                if !isLoading && image != nil {
                    VStack {
                        Spacer()
                        FloatingImageActionBar(
                            isStarred: isStarred,
                            onStarTap: toggleStar,
                            onShareTap: shareImage
                        )
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationTitle(link.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        markAsRead()
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            saveToPhotos()
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }

                        Button(role: .destructive) {
                            deleteImage()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isStarred = currentLink?.isStarred ?? link.isStarred
            loadImage()
        }
        .onChange(of: currentLink?.isStarred) { oldValue, newValue in
            if let newValue = newValue {
                isStarred = newValue
            }
        }
    }

    private func loadImage() {
        Task {
            if let imageURL = await ImageStorageManager.shared.getImageURL(for: link.id, thumbnail: false),
               let data = try? Data(contentsOf: imageURL),
               let loadedImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadError = NSError(domain: "ImageViewer", code: 404)
                    self.isLoading = false
                }
            }
        }
    }

    private func toggleStar() {
        var updatedLink = currentLink ?? link
        updatedLink.isStarred.toggle()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isStarred = updatedLink.isStarred
        }

        linkStore.updateLink(updatedLink)
    }

    private func markAsRead() {
        var updatedLink = currentLink ?? link
        updatedLink.isRead = true
        linkStore.updateLink(updatedLink)
    }

    private func shareImage() {
        guard let image = image else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func saveToPhotos() {
        guard let image = image else { return }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }

    private func deleteImage() {
        linkStore.deleteLink(link)
        dismiss()
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("Unable to Load Image")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var currentScale: CGFloat
    @Binding var finalScale: CGFloat
    @Binding var currentOffset: CGSize
    @Binding var finalOffset: CGSize

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(finalScale + currentScale)
                .offset(x: finalOffset.width + currentOffset.width,
                       y: finalOffset.height + currentOffset.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = value - 1
                        }
                        .onEnded { value in
                            finalScale += currentScale
                            currentScale = 0

                            // Limit zoom range
                            if finalScale < 1 {
                                withAnimation(.spring()) {
                                    finalScale = 1
                                }
                            }
                            if finalScale > 5 {
                                finalScale = 5
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            currentOffset = value.translation
                        }
                        .onEnded { value in
                            finalOffset.width += currentOffset.width
                            finalOffset.height += currentOffset.height
                            currentOffset = .zero
                        }
                )
                .onTapGesture(count: 2) {
                    // Double-tap to zoom
                    withAnimation(.spring()) {
                        if finalScale > 1 {
                            finalScale = 1
                            finalOffset = .zero
                        } else {
                            finalScale = 2.5
                        }
                    }
                }
        }
    }
}

struct FloatingImageActionBar: View {
    let isStarred: Bool
    let onStarTap: () -> Void
    let onShareTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onStarTap) {
                HStack(spacing: 8) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(isStarred ? .yellow : .white)
                    Text(isStarred ? "Starred" : "Star")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }

            Button(action: onShareTap) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                    Text("Share")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ImageViewerContainer(
        link: SavedLink.mockLinks[0],
        linkStore: LinkStore()
    )
}
