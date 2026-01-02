import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView to display a YouTube embed player.
/// Usage (sans modifier le code existant) :
/// - Importer et utiliser `YouTubePlayerView(videoURLString: "https://youtu.be/...")`
/// - Si l'URL est un lien YouTube, la vue charge l'iframe embed pour lecture inline.

struct YouTubeWebView: UIViewRepresentable {
    let request: URLRequest

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        // Allow inline playback (important for YouTube embed with playsinline=1)
        config.allowsInlineMediaPlayback = true

        // Allow media playback without requiring an explicit user gesture
        // Use the iOS 10+ API where available, fallback to deprecated property on older runtimes
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.requiresUserActionForMediaPlayback = false
        }

        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = false
        web.backgroundColor = .clear
        web.isOpaque = false
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Handle load errors here if needed
            NSLog("YouTubeWebView navigation failed: %{public}@", error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optionally inject CSS to ensure proper sizing or responsive behavior
            let js = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0'); document.getElementsByTagName('head')[0].appendChild(meta);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

struct YouTubePlayerView: View {
    let videoURLString: String

    @State private var embedRequest: URLRequest?

    var body: some View {
        Group {
            if let req = embedRequest {
                YouTubeWebView(request: req)
                    .frame(height: 240)
                    .cornerRadius(8)
            } else {
                // basic placeholder while evaluating URL
                Rectangle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 240)
                    .cornerRadius(8)
                    .overlay(Text("Chargement vidéo...").foregroundColor(.secondary))
            }
        }
        .onAppear { prepareRequest() }
    }

    private func prepareRequest() {
        // Try to get a YouTube video id from multiple URL formats
        if let videoId = extractYouTubeId(from: videoURLString) {
            // Build embed URL with playsinline for inline playback
            // Use youtube-nocookie domain as an option to reduce cookie prompts
            let embed = "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&rel=0"
            if let url = URL(string: embed) {
                let req = URLRequest(url: url)
                embedRequest = req
                return
            }
        }

        // Fallback: if it's not a recognized YouTube link, try loading the original URL
        if let url = URL(string: videoURLString) {
            embedRequest = URLRequest(url: url)
        }
    }

    private func extractYouTubeId(from urlString: String) -> String? {
        // Handles formats like:
        // - https://youtu.be/VIDEO_ID
        // - https://www.youtube.com/watch?v=VIDEO_ID
        // - https://www.youtube.com/embed/VIDEO_ID
        // - may include additional query params
        guard let url = URLComponents(string: urlString) else { return nil }

        // 1) youtu.be short link -> path component after /
        if let host = url.host, host.contains("youtu.be") {
            // path may be "/VIDEO_ID"
            if let id = url.path.split(separator: "/").last {
                return String(id)
            }
        }

        // 2) youtube.com watch?v=VIDEO_ID
        if let host = url.host, host.contains("youtube.com") {
            if let queryItems = url.queryItems {
                if let v = queryItems.first(where: { $0.name == "v" })?.value {
                    return v
                }
                // Some URLs include 'si' param or others; also handle `v=` in path
            }

            // 3) embed URL path: /embed/VIDEO_ID
            let segments = url.path.split(separator: "/")
            if let embedIndex = segments.firstIndex(of: "embed"), embedIndex + 1 < segments.count {
                return String(segments[embedIndex + 1])
            }
        }

        // 4) try to parse last path component as a fallback
        if let last = url.path.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }

        return nil
    }
}

// Usage example (à insérer dans une vue existante si tu veux tester):
// YouTubePlayerView(videoURLString: "https://youtu.be/UTO-GzRXF-Q?si=Sh61z_odPPuDtYH7")
