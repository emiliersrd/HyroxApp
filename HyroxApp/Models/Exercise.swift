import Foundation

struct Exercise: Identifiable, Codable {
    let id: UUID
    let title: String
    let shortDescription: String
    let longDescription: String
    let videoURLString: String?

    var videoURL: URL? {
        guard let s = videoURLString else { return nil }
        return URL(string: s)
    }

    init(id: UUID = UUID(), title: String, shortDescription: String, longDescription: String, videoURLString: String? = nil) {
        self.id = id
        self.title = title
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.videoURLString = videoURLString
    }
}
