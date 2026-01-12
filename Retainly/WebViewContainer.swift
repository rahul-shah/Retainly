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

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(
                    url: link.url,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    webView: $webView,
                    onLoadComplete: { saveOffline() }
                )

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
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

                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 20) {
                        Button {
                            webView?.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!canGoBack)

                        Button {
                            webView?.goForward()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!canGoForward)

                        Spacer()

                        Button {
                            webView?.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }

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

    private func saveOffline() {
        Task {
            await OfflineContentManager.shared.saveContent(for: link)

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

#Preview {
    WebViewContainer(
        link: SavedLink.mockLinks[0],
        linkStore: LinkStore()
    )
}
