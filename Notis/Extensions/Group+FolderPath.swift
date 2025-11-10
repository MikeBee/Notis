//
//  Group+FolderPath.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import CoreData

extension Group {
    /// Generate the filesystem folder path for this group
    /// Returns path like "Parent/Child" for nested groups
    func folderPath() -> String {
        var pathComponents: [String] = []
        var currentGroup: Group? = self

        // Build path from leaf to root
        while let group = currentGroup {
            let sanitizedName = sanitizeFilename(group.name ?? "Untitled")
            pathComponents.insert(sanitizedName, at: 0)
            currentGroup = group.parent
        }

        return pathComponents.joined(separator: "/")
    }

    /// Sanitize a filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "-")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
