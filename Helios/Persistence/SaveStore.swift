//
//  SaveStore.swift
//  Helios
//
//  Created by Bernat on 04/09/2026.
//


// SaveStore.swift
// Reads and writes GameSave as JSON at
// .applicationSupportDirectory/Helios/save.json. Not UserDefaults — this
// payload grows with the empire, and UserDefaults is the wrong home for a
// document. Phase 1.5 Step 6.

import Foundation

enum SaveStore {
    private static let directoryName = "Helios"
    private static let fileName = "save.json"
    private static let corruptFileName = "save.corrupt.json"

    /// The version this build knows how to load. A `GameSave.version` other
    /// than this is treated exactly like a corrupt file: some other build
    /// (older or newer) wrote it, and this one has no migration for it yet.
    static let supportedVersion = 1

    private enum StoreError: Error {
        case noApplicationSupportDirectory
    }

    private static func directoryURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { throw StoreError.noApplicationSupportDirectory }
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Writes `save` atomically, creating the Helios directory first if it
    /// doesn't exist yet. `.atomic` means the OS writes to a temp file and
    /// swaps it in — a crash mid-write leaves either the old save or the
    /// fully-written new one, never a truncated file.
    static func save(_ save: GameSave) {
        do {
            let directory = try directoryURL()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(save)
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            // Losing one autosave isn't fatal — the game keeps running in
            // memory and gets another chance at the next scenePhase
            // transition. Nowhere better to surface this yet.
            print("SaveStore: failed to save — \(error)")
        }
    }

    /// Loads the save, or `nil` if there isn't one, it's corrupt, or it's a
    /// version this build doesn't understand. Never throws — `GameState.load()`
    /// falls back to `.seeded()` in every one of those cases, so a bad file
    /// can never crash launch.
    ///
    /// A corrupt or unsupported-version file is moved aside to
    /// `save.corrupt.json` (replacing any earlier one) so it can be
    /// inspected, rather than silently destroyed — and so it doesn't fail
    /// launch the same way again on every subsequent attempt.
    static func load() -> GameSave? {
        guard let directory = try? directoryURL() else { return nil }
        let fileURL = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        guard
            let data = try? Data(contentsOf: fileURL),
            let save = try? JSONDecoder().decode(GameSave.self, from: data),
            save.version == supportedVersion
        else {
            quarantine(fileURL, in: directory)
            return nil
        }

        return save
    }

    private static func quarantine(_ fileURL: URL, in directory: URL) {
        let corruptURL = directory.appendingPathComponent(corruptFileName)
        try? FileManager.default.removeItem(at: corruptURL)
        try? FileManager.default.moveItem(at: fileURL, to: corruptURL)
    }
}