import Foundation

public actor SnapshotStore {
    private let fileURL: URL
    private let legacyFileURL: URL?
    private let maxSnapshots = 25

    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.fileURL = directoryURL.appendingPathComponent("snapshots.json")
            self.legacyFileURL = nil
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.fileURL = appSupport
                .appendingPathComponent("DefaultAppSwitcher", isDirectory: true)
                .appendingPathComponent("snapshots.json")
            self.legacyFileURL = appSupport
                .appendingPathComponent("VarsayilanYoneticisi", isDirectory: true)
                .appendingPathComponent("snapshots.json")
        }
    }

    public func loadAll() -> [ResetSnapshot] {
        let sourceURL: URL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            sourceURL = fileURL
        } else if let legacyFileURL, FileManager.default.fileExists(atPath: legacyFileURL.path) {
            sourceURL = legacyFileURL
        } else {
            return []
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([ResetSnapshot].self, from: data)
            return decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }

    public func save(_ snapshot: ResetSnapshot) throws {
        var existing = loadAll()
        existing.removeAll { $0.id == snapshot.id }
        existing.insert(snapshot, at: 0)
        if existing.count > maxSnapshots {
            existing = Array(existing.prefix(maxSnapshots))
        }
        try persist(existing)
    }

    public func delete(id: UUID) throws {
        var existing = loadAll()
        existing.removeAll { $0.id == id }
        try persist(existing)
    }

    private func persist(_ snapshots: [ResetSnapshot]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshots)
        try data.write(to: fileURL, options: .atomic)
    }
}
