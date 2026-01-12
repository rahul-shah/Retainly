//
//  ContentBlockerRules.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import Foundation
import WebKit

class ContentBlockerManager {
    static let shared = ContentBlockerManager()

    private init() {}

    func setupContentBlocker(for webView: WKWebView, completion: @escaping () -> Void) {
        let rules = """
        [
            {
                "trigger": {
                    "url-filter": ".*",
                    "resource-type": ["script"],
                    "if-domain": [
                        "*doubleclick.net",
                        "*googlesyndication.com",
                        "*googleadservices.com",
                        "*google-analytics.com",
                        "*googletagmanager.com",
                        "*facebook.com",
                        "*facebook.net",
                        "*fbcdn.net",
                        "*twitter.com",
                        "*ads-twitter.com",
                        "*analytics.twitter.com",
                        "*advertising.com",
                        "*taboola.com",
                        "*outbrain.com",
                        "*criteo.com",
                        "*adform.net",
                        "*rubiconproject.com",
                        "*pubmatic.com",
                        "*quantserve.com",
                        "*scorecardresearch.com",
                        "*advertising.com",
                        "*amazon-adsystem.com",
                        "*mediavoice.com",
                        "*media.net"
                    ]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*/ad[sx]?/.*",
                    "resource-type": ["script", "image"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*advertisement.*",
                    "resource-type": ["script", "image"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*banner.*",
                    "resource-type": ["image"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*tracking.*",
                    "resource-type": ["script"]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*analytics.*",
                    "resource-type": ["script"]
                },
                "action": {
                    "type": "block"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ContentBlockingRules",
            encodedContentRuleList: rules
        ) { ruleList, error in
            if let error = error {
                print("Error compiling content rules: \(error.localizedDescription)")
                completion()
                return
            }

            if let ruleList = ruleList {
                webView.configuration.userContentController.add(ruleList)
                print("Content blocking rules applied successfully")
            }

            completion()
        }
    }

    // More aggressive blocking rules
    static let aggressiveBlockingRules = """
    [
        {
            "trigger": {
                "url-filter": ".*",
                "resource-type": ["script", "image", "font"],
                "if-domain": [
                    "*doubleclick.net",
                    "*googlesyndication.com",
                    "*googleadservices.com",
                    "*google-analytics.com",
                    "*googletagmanager.com",
                    "*facebook.com",
                    "*facebook.net",
                    "*fbcdn.net",
                    "*connect.facebook.net",
                    "*twitter.com",
                    "*ads-twitter.com",
                    "*analytics.twitter.com",
                    "*advertising.com",
                    "*taboola.com",
                    "*outbrain.com",
                    "*criteo.com",
                    "*adform.net",
                    "*rubiconproject.com",
                    "*pubmatic.com",
                    "*quantserve.com",
                    "*scorecardresearch.com",
                    "*zqtk.net",
                    "*2mdn.net",
                    "*adsafeprotected.com",
                    "*advertising.com",
                    "*amazon-adsystem.com",
                    "*adsrvr.org",
                    "*adnxs.com",
                    "*casalemedia.com",
                    "*bidswitch.net",
                    "*rlcdn.com",
                    "*contextweb.com",
                    "*serving-sys.com",
                    "*bluekai.com",
                    "*exelator.com",
                    "*pro-market.net",
                    "*youtube.com/ptracking",
                    "*googletagservices.com",
                    "*moatads.com",
                    "*teads.tv"
                ]
            },
            "action": {
                "type": "block"
            }
        },
        {
            "trigger": {
                "url-filter": ".*/ad[sx]?/.*"
            },
            "action": {
                "type": "block"
            }
        },
        {
            "trigger": {
                "url-filter": ".*/(advertisement|banner|popup|sponsor).*"
            },
            "action": {
                "type": "block"
            }
        }
    ]
    """
}
