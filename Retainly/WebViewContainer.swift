//
//  WebViewContainer.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI
import WebKit

struct WebViewContainer: View {
    let link: SavedLink
    @ObservedObject var linkStore: LinkStore
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webView: WKWebView?
    @State private var isReaderMode = false
    @State private var articleContent: ArticleContent?
    @State private var extractionFailed = false
    @State private var isStarred: Bool

    init(link: SavedLink, linkStore: LinkStore) {
        self.link = link
        self.linkStore = linkStore
        _isStarred = State(initialValue: link.isStarred)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isReaderMode {
                    if let article = articleContent {
                        ReaderView(article: article)
                    } else if extractionFailed {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("Unable to extract article content")
                                .font(.headline)
                            Text("Try switching to web view")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Switch to Web View") {
                                isReaderMode = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView("Extracting article content...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    WebView(
                        url: link.url,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        webView: $webView,
                        onLoadComplete: { handleLoadComplete() }
                    )

                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                    }
                }

                // Floating action bar at the bottom
                VStack {
                    Spacer()
                    FloatingActionBar(isStarred: $isStarred, onStarTap: toggleStar)
                        .padding(.bottom, 50) // Space for the toolbar
                }
            }
            .navigationTitle(link.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        markAsRead()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            isReaderMode.toggle()
                        }
                        // Load article content when switching to reader mode
                        if isReaderMode && articleContent == nil && !extractionFailed {
                            Task {
                                await loadCachedArticleContent()
                                // If no cached content and webView is available, extract it
                                if articleContent == nil && webView != nil {
                                    extractArticleContent()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: isReaderMode ? "doc.plaintext" : "doc.text")
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 20) {
                        Button {
                            webView?.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!canGoBack || isReaderMode)
                        .opacity(isReaderMode ? 0.3 : 1)

                        Button {
                            webView?.goForward()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!canGoForward || isReaderMode)
                        .opacity(isReaderMode ? 0.3 : 1)

                        Spacer()

                        Button {
                            webView?.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isReaderMode)
                        .opacity(isReaderMode ? 0.3 : 1)

                        Button {
                            shareLink()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func markAsRead() {
        var updatedLink = link
        updatedLink.isRead = true
        linkStore.updateLink(updatedLink)
    }

    private func toggleStar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isStarred.toggle()
        }
        var updatedLink = link
        updatedLink.isStarred = isStarred
        linkStore.updateLink(updatedLink)
    }

    private func loadCachedArticleContent() async {
        // Check if we have cached article content
        if let cachedArticle = await OfflineContentManager.shared.getArticleContent(for: link.id) {
            await MainActor.run {
                self.articleContent = cachedArticle
                print("✅ Loaded cached article content for: \(link.title)")
            }
        }
    }

    private func handleLoadComplete() {
        saveOffline()
        extractArticleContent()
    }

    private func extractArticleContent() {
        guard let webView = webView else { return }

        Task {
            do {
                let content = try await ReadabilityParser.extractFromWebView(webView)
                await MainActor.run {
                    self.articleContent = content
                    self.extractionFailed = false
                    print("✅ Successfully extracted article content: \(content.title)")
                }
            } catch {
                await MainActor.run {
                    self.extractionFailed = true
                    print("❌ Failed to extract article content: \(error)")
                }
            }
        }
    }

    private func saveOffline() {
        Task {
            await OfflineContentManager.shared.saveContent(for: link, articleContent: articleContent)

            // Update link to mark as cached
            var updatedLink = link
            updatedLink.isOfflineCached = true
            linkStore.updateLink(updatedLink)
        }
    }

    private func shareLink() {
        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [link.url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
        #endif
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webView: WKWebView?
    var onLoadComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Set up content blocking
        ContentBlockerManager.shared.setupContentBlocker(for: webView) {
            // Load URL after content blocker is set up
            let request = URLRequest(url: self.url)
            webView.load(request)
        }

        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Content loading is now handled in makeUIView after content blocker setup
        // Only reload if the URL has changed and it's already loaded
        if webView.url != url && webView.url != nil {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.onLoadComplete()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

struct FloatingActionBar: View {
    @Binding var isStarred: Bool
    let onStarTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onStarTap) {
                HStack(spacing: 8) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(isStarred ? .yellow : .primary)
                    Text(isStarred ? "Starred" : "Star")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    WebViewContainer(
        link: SavedLink.mockLinks[0],
        linkStore: LinkStore()
    )
}
