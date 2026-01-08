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

    // Try to find a local video in the app bundle for a given exercise title.
    // We try a few filename variants to be forgiving about naming and accept common video extensions.
    private func localCoachURL(for title: String) -> URL? {
        // candidate resource names (no extension)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let underscored = trimmed.replacingOccurrences(of: " ", with: "_")
        let lower = underscored.lowercased()
        let candidates = [trimmed, underscored, lower, "\(trimmed)_coach", "\(underscored)_coach", "\(lower)_coach"]

        // extensions to check (in order)
        let exts = ["mp4", "mov", "m4v"]

        // 1) Try the usual bundle lookup (resource at bundle root) for each extension
        for ext in exts {
            for name in candidates {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }

        // 2) Fallback: scan resources in likely subdirectories (e.g. a folder named "Ressources")
        let subdirsToCheck = ["Ressources", "Resources"]
        for sub in subdirsToCheck {
            for ext in exts {
                if let all = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: sub) {
                    for url in all {
                        let base = url.deletingPathExtension().lastPathComponent
                        if candidates.contains(base) {
                            return url
                        }
                    }
                }
            }
        }

        // 3) As a last resort scan all known video extensions in the bundle root
        for ext in exts {
            if let allRoot = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in allRoot {
                    let base = url.deletingPathExtension().lastPathComponent
                    if candidates.contains(base) {
                        return url
                    }
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
        .toolbar {
            // Debug button: list local .mp4s found in the bundle (useful to verify resources)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    self.localFiles = findAllLocalVideos()
                     showDebugSheet = true
                 }) {
                     Image(systemName: "magnifyingglass")
                 }
             }
         }
         .sheet(isPresented: $showDebugSheet) {
             NavigationView {
                 List(localFiles, id: \.self) { url in
                     VStack(alignment: .leading) {
                         Text(url.lastPathComponent)
                             .font(.body)
                         Text(url.path)
                             .font(.caption)
                             .foregroundColor(.secondary)
                     }
                     .padding(.vertical, 4)
                 }
                .navigationTitle("Local Videos")
                 .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { showDebugSheet = false } } }
             }
         }
     }

    // Debug state & helpers
    @State private var showDebugSheet: Bool = false
    @State private var localFiles: [URL] = []

    /// Return all local video URLs with common extensions found in the bundle root and common subdirectories
    private func findAllLocalVideos() -> [URL] {
        let exts = ["mp4", "mov", "m4v"]
        var results: [URL] = []
        // check root for each extension
        for ext in exts {
            if let root = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                results.append(contentsOf: root)
            }
        }
        // check common subfolders
        for sub in ["Ressources", "Resources"] {
            for ext in exts {
                if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: sub) {
                    results.append(contentsOf: urls)
                }
            }
        }
        // dedupe and sort
        let unique = Array(Set(results)).sorted { $0.lastPathComponent < $1.lastPathComponent }
        return unique
    }
}

struct CompareListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CompareListView()
        }
    }
}
