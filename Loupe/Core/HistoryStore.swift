import AppKit

struct HistoryItem: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let createdAt: Date
}

final class HistoryStore {
    static let shared = HistoryStore()
    private let maxItems = 20
    private(set) var items: [HistoryItem] = []

    private var folderURL: URL {
        PreferencesStore.shared.saveFolderURL
    }
    private var indexURL: URL {
        folderURL.appendingPathComponent(".loupe_history.json")
    }

    private init() {
        loadIndex()
    }

    @discardableResult
    func save(image: NSImage) -> URL? {
        let folder = folderURL
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let fileName = "Loupe \(formatter.string(from: Date())).png"
        let fileURL = folder.appendingPathComponent(fileName)

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        do {
            try pngData.write(to: fileURL)
        } catch {
            return nil
        }

        let item = HistoryItem(id: UUID(), fileName: fileName, createdAt: Date())
        items.insert(item, at: 0)
        if items.count > maxItems {
            let overflow = items.count - maxItems
            let removed = Array(items.suffix(overflow))
            items.removeLast(overflow)
            for r in removed {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(r.fileName))
            }
        }
        saveIndex()
        return fileURL
    }

    func url(for item: HistoryItem) -> URL {
        folderURL.appendingPathComponent(item.fileName)
    }

    func image(for item: HistoryItem) -> NSImage? {
        NSImage(contentsOf: url(for: item))
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL)
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        items = decoded
    }
}
