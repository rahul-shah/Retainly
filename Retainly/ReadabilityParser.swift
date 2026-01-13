//
//  ReadabilityParser.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation
import WebKit

class ReadabilityParser {

    /// Extracts main article content from HTML
    static func extractArticleContent(from html: String, baseURL: URL) -> ArticleContent? {
        // Use JavaScript-based readability extraction
        let script = """
        (function() {
            try {
                // Simple content extraction algorithm
                var article = document.querySelector('article') ||
                             document.querySelector('[role="main"]') ||
                             document.querySelector('main') ||
                             document.querySelector('.post-content') ||
                             document.querySelector('.article-content') ||
                             document.querySelector('.entry-content') ||
                             document.body;

                if (!article) return null;

                // Get article title
                var title = document.querySelector('h1')?.textContent ||
                           document.querySelector('meta[property="og:title"]')?.content ||
                           document.title || '';

                // Get article author
                var author = document.querySelector('meta[name="author"]')?.content ||
                            document.querySelector('[rel="author"]')?.textContent ||
                            document.querySelector('.author')?.textContent || '';

                // Clone the article to avoid modifying the original
                var content = article.cloneNode(true);

                // Remove unwanted elements
                var selectorsToRemove = [
                    'script', 'style', 'nav', 'header', 'footer', 'aside',
                    '.ad', '.advertisement', '.social-share', '.comments',
                    '.related-posts', '.sidebar', '[role="complementary"]',
                    '.cookie-notice', '.newsletter', '.popup'
                ];

                selectorsToRemove.forEach(function(selector) {
                    content.querySelectorAll(selector).forEach(function(el) {
                        el.remove();
                    });
                });

                // Get the cleaned HTML
                var html = content.innerHTML;

                // Get plain text for excerpt
                var textContent = content.textContent || '';
                textContent = textContent.replace(/\\s+/g, ' ').trim();

                return {
                    title: title.trim(),
                    author: author.trim(),
                    html: html,
                    text: textContent
                };
            } catch(e) {
                return null;
            }
        })();
        """

        return nil // This will be executed in WKWebView context
    }

    /// Executes readability extraction in a WKWebView
    static func extractFromWebView(_ webView: WKWebView) async throws -> ArticleContent {
        let script = """
        (function() {
            try {
                // Get article title
                var title = document.querySelector('h1')?.textContent ||
                           document.querySelector('meta[property="og:title"]')?.content ||
                           document.title || '';

                // Get article author
                var author = document.querySelector('meta[name="author"]')?.content ||
                            document.querySelector('[rel="author"]')?.textContent ||
                            document.querySelector('.author')?.textContent || '';

                // Find main content
                var article = document.querySelector('article') ||
                             document.querySelector('[role="main"]') ||
                             document.querySelector('main') ||
                             document.querySelector('.post-content') ||
                             document.querySelector('.article-content') ||
                             document.querySelector('.entry-content') ||
                             document.querySelector('.post') ||
                             document.body;

                if (!article) {
                    return { title: title, author: author, html: '', text: '' };
                }

                // Clone to avoid modifying original
                var content = article.cloneNode(true);

                // Remove unwanted elements
                var selectorsToRemove = [
                    'script', 'style', 'nav', 'header:not(article header)',
                    'footer:not(article footer)', 'aside', '.ad', '.ads',
                    '.advertisement', '.social-share', '.share-buttons',
                    '.comments', '.comment-section', '.related-posts',
                    '.sidebar', '[role="complementary"]', '.cookie-notice',
                    '.newsletter', '.popup', '.modal', 'iframe[src*="ads"]',
                    '[class*="promo"]', '[id*="promo"]', '.sponsored'
                ];

                selectorsToRemove.forEach(function(selector) {
                    content.querySelectorAll(selector).forEach(function(el) {
                        el.remove();
                    });
                });

                // Make all links absolute
                content.querySelectorAll('a[href]').forEach(function(link) {
                    var href = link.getAttribute('href');
                    if (href && !href.startsWith('http')) {
                        link.href = new URL(href, window.location.href).href;
                    }
                });

                // Make all images absolute
                content.querySelectorAll('img[src]').forEach(function(img) {
                    var src = img.getAttribute('src');
                    if (src && !src.startsWith('http') && !src.startsWith('data:')) {
                        img.src = new URL(src, window.location.href).href;
                    }
                });

                var html = content.innerHTML;
                var text = content.textContent || '';
                text = text.replace(/\\s+/g, ' ').trim();

                return {
                    title: title.trim(),
                    author: author.trim(),
                    html: html,
                    text: text.substring(0, 1000)
                };
            } catch(e) {
                return { title: '', author: '', html: '', text: '', error: e.toString() };
            }
        })();
        """

        let result = try await webView.evaluateJavaScript(script)

        guard let dict = result as? [String: String],
              let title = dict["title"],
              let html = dict["html"] else {
            throw ReadabilityError.extractionFailed
        }

        return ArticleContent(
            title: title.isEmpty ? "Article" : title,
            author: dict["author"],
            html: html,
            text: dict["text"] ?? ""
        )
    }
}

struct ArticleContent: Codable {
    let title: String
    let author: String?
    let html: String
    let text: String
}

enum ReadabilityError: Error {
    case extractionFailed
    case invalidHTML
}
