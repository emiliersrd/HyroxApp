import SwiftUI

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (YouTube thumbnail if available)
            if let videoString = exercise.videoURLString, let thumbURL = YouTubeHelper.thumbnailURL(from: videoString) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 96, height: 72)
                            .cornerRadius(8)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 72)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(Image(systemName: "play.circle.fill").resizable().scaledToFit().frame(width: 28).foregroundColor(.white).shadow(radius: 2))
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 96, height: 72)
                            .cornerRadius(8)
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 96, height: 72)
                            .cornerRadius(8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 96, height: 72)
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if exercise.videoURL != nil {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            } else {
                                Text("Vid")
                                    .foregroundColor(.white)
                            }
                        }
                    )
            }

            VStack(alignment: .leading) {
                Text(exercise.title)
                    .font(.headline)
                Text(exercise.shortDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct ExerciseRow_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseRow(exercise: Exercise(title: "Burpee", shortDescription: "Full body explosive movement", longDescription: "Long description here", videoURLString: "https://youtu.be/UTO-GzRXF-Q"))
            .previewLayout(.sizeThatFits)
    }
}
