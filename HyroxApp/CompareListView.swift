import SwiftUI

/// Small list view that shows exercise names; tapping one navigates to CompareVideosView
/// with a preloaded coach video for quick compare. Coach URLs are stored locally here
/// (assumption: coach videos for comparison are different from HowToTrain videos).
struct CompareListView: View {
    // Minimal list of Hyrox exercises (titles only)
    private let exercises = [
        "Wall Balls",
        "Sled Pull",
        "Lunges",
        "Rowing",
        "Burpee",
        "Farmer's Carry",
        "SkiErg"
    ]

    // Mapping from exercise title -> coach video URL string used specifically for Compare
    // ASSUMPTION: These are coach compare videos (different from HowToTrain). Replace URLs as needed.
    private let coachVideoMap: [String: String] = [
        "Wall Balls": "https://youtu.be/bm7QLEOx26c",
        "Sled Pull": "https://youtu.be/K2FhsenkS3U",
        "Lunges": "https://youtu.be/YlFsbfK5Doc",
        "Rowing": "https://youtu.be/KI_TkxBSFOI",
        "Burpee": "https://youtu.be/UTO-GzRXF-Q",
        "Farmer's Carry": "https://youtu.be/EXAMPLE",
        // Added SkiErg coach video for Compare (different from HowToTrain video)
        "SkiErg": "https://youtu.be/EXAMPLE_SKIERG"
    ]

    // Try to find a local MP4 in the app bundle for a given exercise title.
    // We try a few filename variants to be forgiving about naming.
    private func localCoachURL(for title: String) -> URL? {
        // candidate resource names (no extension)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let underscored = trimmed.replacingOccurrences(of: " ", with: "_")
        let lower = underscored.lowercased()
        let candidates = [trimmed, underscored, lower, "\(trimmed)_coach", "\(underscored)_coach", "\(lower)_coach"]

        // 1) Try the usual bundle lookup (resource at bundle root)
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                return url
            }
        }

        // 2) Fallback: scan mp4 resources in likely subdirectories (e.g. a folder named "Ressources")
        let subdirsToCheck = ["Ressources", "Resources", nil].compactMap { $0 }
        for sub in subdirsToCheck {
            if let all = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: sub) {
                for url in all {
                    let base = url.deletingPathExtension().lastPathComponent
                    if candidates.contains(base) {
                        return url
                    }
                }
            }
        }

        // 3) As a last resort scan all mp4s in the bundle root (covers folders added differently)
        if let allRoot = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) {
            for url in allRoot {
                let base = url.deletingPathExtension().lastPathComponent
                if candidates.contains(base) {
                    return url
                }
            }
        }

        return nil
    }

    var body: some View {
        List(exercises, id: \ .self) { title in
            // Prefer a local mp4 if present in the bundle
            if let local = localCoachURL(for: title) {
                NavigationLink(destination: CompareVideosView(coachURL: local)) {
                    HStack { Text(title); Spacer(); Text("local").font(.caption).foregroundColor(.secondary) }
                        .padding(.vertical, 8)
                }
            } else if let str = coachVideoMap[title], let url = URL(string: str) {
                NavigationLink(destination: CompareVideosView(coachURL: url)) {
                    Text(title)
                        .padding(.vertical, 8)
                }
            } else {
                // Fallback: open CompareVideosView without preloaded coach video
                NavigationLink(destination: CompareVideosView()) {
                    Text(title)
                        .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Compare Exercises")
    }
}

struct CompareListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CompareListView()
        }
    }
}
