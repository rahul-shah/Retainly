//
//  SidebarCategory.swift
//  Retainly
//
//  Created by Rahul Shah on 12/01/2026.
//

import SwiftUI

enum SidebarCategory: String, CaseIterable, Identifiable {
    case unread = "Unread"
    case read = "Read"
    case starred = "Starred"
    case highlighted = "Highlighted"
    case all = "All"
    case recentlyDeleted = "Recently Deleted"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .unread:
            return "envelope"
        case .read:
            return "envelope.open"
        case .starred:
            return "star"
        case .highlighted:
            return "highlighter"
        case .all:
            return "tray.full"
        case .recentlyDeleted:
            return "trash"
        }
    }
}
