import SwiftUI
import AVKit

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.title)
                    .font(.largeTitle)
                    .bold()

                if let videoString = exercise.videoURLString {
                    if isYouTubeLink(videoString) {
                        // Use the YouTube embed web view for YouTube links
                        YouTubePlayerView(videoURLString: videoString)
                            .frame(height: 240)
                            .cornerRadius(8)
                    } else if let url = URL(string: videoString) {
                        // Use AVPlayer for direct media URLs (mp4, m3u8, ...)
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 240)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 240)
                            .cornerRadius(8)
                            .overlay(Text("Lien vidéo invalide").foregroundColor(.secondary))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 240)
                        .cornerRadius(8)
                        .overlay(Text("No video available").foregroundColor(.secondary))
                }

                Text("Description")
                    .font(.headline)
                Text(exercise.longDescription)
                    .font(.body)

                // Compare with coach button: opens CompareVideosView preloaded with coach video
                if let coachURL = exercise.videoURL {
                    NavigationLink(destination: CompareVideosView(coachURL: coachURL)) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                            Text("Compare with coach")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(exercise.title)
    }

    // Helper to detect YouTube URLs (basic detection covering common formats)
    private func isYouTubeLink(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString.lowercased()) else { return false }
        if let host = components.host {
            if host.contains("youtube.com") || host.contains("youtu.be") {
                return true
            }
        }
        // also check for common youtube path fragments
        if urlString.contains("youtube.com/watch") || urlString.contains("youtu.be/") || urlString.contains("/embed/") {
            return true
        }
        return false
    }
}

struct ExerciseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseDetailView(exercise: Exercise(title: "Burpee", shortDescription: "Explosive", longDescription: "Detailed coaching tips go here.", videoURLString: "https://youtu.be/UTO-GzRXF-Q?si=Sh61z_odPPuDtYH7"))
    }
}
