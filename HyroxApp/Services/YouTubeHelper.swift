import Foundation
import UIKit

enum YouTubeHelper {
    /// Extracts the YouTube video id from common URL formats.
    static func videoID(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString) else { return nil }
        if let host = components.host, host.contains("youtu.be") {
            if let id = components.path.split(separator: "/").last {
                return String(id)
            }
        }
        if let host = components.host, host.contains("youtube.com") {
            // watch?v=ID
            if let items = components.queryItems {
                if let v = items.first(where: { $0.name == "v" })?.value { return v }
            }
            // embed/ID
            let parts = components.path.split(separator: "/")
            if let embedIndex = parts.firstIndex(of: "embed"), embedIndex + 1 < parts.count {
                return String(parts[embedIndex + 1])
            }
        }
        // fallback: last path component
        if let last = components.path.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }
        return nil
    }

    /// Returns a high quality thumbnail URL for a YouTube video ID
    static func thumbnailURL(forVideoID id: String, quality: String = "hqdefault") -> URL? {
        // quality can be: default, mqdefault, hqdefault, sddefault, maxresdefault
        return URL(string: "https://img.youtube.com/vi/\(id)/\(quality).jpg")
    }

    /// Convenience to get thumbnail URL from any YouTube link
    static func thumbnailURL(from urlString: String, quality: String = "hqdefault") -> URL? {
        guard let id = videoID(from: urlString) else { return nil }
        return thumbnailURL(forVideoID: id, quality: quality)
    }
}
