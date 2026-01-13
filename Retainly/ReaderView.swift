//
//  ReaderView.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI
import WebKit

struct ReaderView: View {
    let article: ArticleContent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Article title
                Text(article.title)
                    .font(.system(size: 32, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                // Author if available
                if let author = article.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 10)

                // Article content
                ReaderHTMLView(html: formattedHTML)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 700) // Optimal reading width
            .frame(maxWidth: .infinity)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }

    private var formattedHTML: String {
        let backgroundColor = colorScheme == .dark ? "#000000" : "#FFFFFF"
        let textColor = colorScheme == .dark ? "#FFFFFF" : "#000000"
        let secondaryColor = colorScheme == .dark ? "#AAAAAA" : "#666666"

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 18px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: \(backgroundColor);
                    padding: 0;
                    margin: 0;
                }

                p {
                    margin-bottom: 1.2em;
                }

                h1, h2, h3, h4, h5, h6 {
                    margin-top: 1.5em;
                    margin-bottom: 0.8em;
                    font-weight: 600;
                    line-height: 1.3;
                }

                h1 { font-size: 2em; }
                h2 { font-size: 1.6em; }
                h3 { font-size: 1.3em; }
                h4 { font-size: 1.1em; }

                a {
                    color: #007AFF;
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 1.5em auto;
                    border-radius: 8px;
                }

                blockquote {
                    margin: 1.5em 0;
                    padding-left: 1.2em;
                    border-left: 4px solid \(secondaryColor);
                    color: \(secondaryColor);
                    font-style: italic;
                }

                code {
                    font-family: 'SF Mono', Monaco, 'Courier New', monospace;
                    background-color: \(colorScheme == .dark ? "#1C1C1E" : "#F2F2F7");
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                    font-size: 0.9em;
                }

                pre {
                    background-color: \(colorScheme == .dark ? "#1C1C1E" : "#F2F2F7");
                    padding: 1em;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1.5em 0;
                }

                pre code {
                    background-color: transparent;
                    padding: 0;
                }

                ul, ol {
                    margin: 1em 0;
                    padding-left: 2em;
                }

                li {
                    margin-bottom: 0.5em;
                }

                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1.5em 0;
                }

                th, td {
                    padding: 0.8em;
                    border: 1px solid \(secondaryColor);
                    text-align: left;
                }

                th {
                    background-color: \(colorScheme == .dark ? "#1C1C1E" : "#F2F2F7");
                    font-weight: 600;
                }

                hr {
                    border: none;
                    border-top: 1px solid \(secondaryColor);
                    margin: 2em 0;
                }

                figure {
                    margin: 1.5em 0;
                }

                figcaption {
                    text-align: center;
                    color: \(secondaryColor);
                    font-size: 0.9em;
                    margin-top: 0.5em;
                }
            </style>
        </head>
        <body>
            \(article.html)
        </body>
        </html>
        """
    }
}

struct ReaderHTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false // Parent ScrollView handles scrolling
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#Preview {
    ReaderView(article: ArticleContent(
        title: "The Future of Swift Development",
        author: "John Appleseed",
        html: """
        <p>This is a sample article with some content. It demonstrates how the reader view will display article content in a clean, distraction-free format.</p>
        <h2>A Subheading</h2>
        <p>More content here with <a href="https://example.com">a link</a> and some <strong>bold text</strong>.</p>
        <blockquote>This is a quote from someone important.</blockquote>
        <p>And here's more content after the quote.</p>
        """,
        text: "Sample text"
    ))
}
