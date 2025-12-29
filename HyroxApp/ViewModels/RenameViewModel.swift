import Foundation
import Combine

@MainActor
class RenameViewModel: ObservableObject {
    @Published var currentName: String?

    private let userDefaultsKey = "com.hyroxapp.label.currentName"

    init() {
        load()
    }

    func load() {
        currentName = UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    func save(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: userDefaultsKey)
        currentName = trimmed
    }
}
