import Foundation
import Combine
import os

/// Persistent store for user profiles and app-wide settings.
///
/// - Persists to `~/Library/Application Support/DualSenseRemap/` as two JSON
///   files (`profiles.json` + `settings.json`), written atomically.
/// - Autosaves 0.5 s after any change (Combine debounce on the three
///   published properties).
/// - Seeds `Profile.defaultProfile()` + `Profile.mediaProfile()` on first run.
/// - Never allows an empty profile list: a fresh default profile is recreated
///   when the last one is deleted.
/// - All `@Published` mutations happen on the main thread; the public mutating
///   methods can be called from any thread and hop to main as needed.
final class ProfileStore: ObservableObject {

    static let shared = ProfileStore()

    // MARK: - Published state

    @Published var profiles: [Profile]
    @Published var activeProfileID: UUID?
    @Published var settings: AppSettings

    /// The currently active profile. Falls back to the first profile (the
    /// store never holds zero profiles) or, as a last resort, a fresh default.
    var activeProfile: Profile {
        if let id = activeProfileID, let match = profiles.first(where: { $0.id == id }) {
            return match
        }
        return profiles.first ?? Profile.defaultProfile()
    }

    // MARK: - Private state

    private var cancellables = Set<AnyCancellable>()
    /// Serial queue for disk I/O so saves never block the main thread.
    private let persistenceQueue = DispatchQueue(label: "com.dualsenseremap.profilestore.io", qos: .utility)
    private static let logger = Logger(subsystem: "com.dualsenseremap.app", category: "ProfileStore")

    /// On-disk layout of `profiles.json`.
    ///
    /// Note: `Profile.mappings` is `[ControllerElement: Action]`; the default
    /// synthesized `Codable` conformance encodes it as an array of alternating
    /// keys and values (non-String dictionary keys). This is intentional and
    /// symmetric on decode — do not add custom key-encoding strategies.
    private struct ProfilesDocument: Codable {
        var profiles: [Profile]
        var activeProfileID: UUID?
    }

    // MARK: - Storage locations

    private static var storageDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("DualSenseRemap", isDirectory: true)
    }

    private static var profilesFileURL: URL {
        storageDirectoryURL.appendingPathComponent("profiles.json")
    }

    private static var settingsFileURL: URL {
        storageDirectoryURL.appendingPathComponent("settings.json")
    }

    // MARK: - Init / loading

    private init() {
        let decoder = JSONDecoder()

        var initialProfiles: [Profile] = []
        var initialActiveID: UUID?
        var initialSettings = AppSettings()
        var isFirstRun = false

        if let data = try? Data(contentsOf: Self.profilesFileURL) {
            if let document = try? decoder.decode(ProfilesDocument.self, from: data) {
                initialProfiles = document.profiles
                initialActiveID = document.activeProfileID
            } else {
                Self.logger.error("profiles.json could not be decoded — reseeding built-in profiles")
            }
        }

        if let data = try? Data(contentsOf: Self.settingsFileURL),
           let decoded = try? decoder.decode(AppSettings.self, from: data) {
            initialSettings = decoded
        }

        // First run (or corrupted/empty file): seed the built-in profiles.
        if initialProfiles.isEmpty {
            initialProfiles = [Profile.defaultProfile(), Profile.mediaProfile()]
            initialActiveID = initialProfiles.first?.id
            isFirstRun = true
        }

        // Validate the restored active ID; fall back to the first profile.
        if initialActiveID == nil || !initialProfiles.contains(where: { $0.id == initialActiveID }) {
            initialActiveID = initialProfiles.first?.id
        }

        self.profiles = initialProfiles
        self.activeProfileID = initialActiveID
        self.settings = initialSettings

        setUpAutosave()

        if isFirstRun {
            save()
        }
    }

    // MARK: - Autosave

    /// Debounced autosave: any change to profiles, active profile, or settings
    /// triggers a save 0.5 s after the last mutation.
    private func setUpAutosave() {
        Publishers.MergeMany([
            $profiles.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $activeProfileID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $settings.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ])
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in self?.save() }
        .store(in: &cancellables)
    }

    // MARK: - Persistence

    /// Snapshots the current state on the main thread and writes both JSON
    /// files atomically on a background queue.
    func save() {
        runOnMain {
            let document = ProfilesDocument(profiles: self.profiles, activeProfileID: self.activeProfileID)
            let settings = self.settings
            self.persistenceQueue.async {
                Self.write(document: document, settings: settings)
            }
        }
    }

    private static func write(document: ProfilesDocument, settings: AppSettings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
            let profilesData = try encoder.encode(document)
            try profilesData.write(to: profilesFileURL, options: .atomic)
            let settingsData = try encoder.encode(settings)
            try settingsData.write(to: settingsFileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist store: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Profile management

    func addProfile(_ profile: Profile) {
        runOnMain {
            self.profiles.append(profile)
        }
    }

    /// Replaces the stored profile with the same `id`; appends it when the id
    /// is unknown (defensive — keeps UI edits from being silently dropped).
    func updateProfile(_ profile: Profile) {
        runOnMain {
            if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                self.profiles[index] = profile
            } else {
                self.profiles.append(profile)
            }
        }
    }

    /// Deletes a profile. Deleting the active profile activates the first
    /// remaining one; deleting the last profile recreates a default profile
    /// so the store never holds zero profiles.
    func deleteProfile(id: UUID) {
        runOnMain {
            self.profiles.removeAll { $0.id == id }
            if self.profiles.isEmpty {
                self.profiles = [Profile.defaultProfile()]
            }
            if !self.profiles.contains(where: { $0.id == self.activeProfileID }) {
                self.activeProfileID = self.profiles.first?.id
            }
        }
    }

    func activateProfile(id: UUID) {
        runOnMain {
            guard self.profiles.contains(where: { $0.id == id }) else { return }
            guard self.activeProfileID != id else { return }
            self.activeProfileID = id
        }
    }

    /// Activates the next profile in list order (wraps around).
    func cycleProfile() {
        runOnMain {
            guard !self.profiles.isEmpty else { return }
            let currentID = self.activeProfile.id
            guard let index = self.profiles.firstIndex(where: { $0.id == currentID }) else {
                self.activeProfileID = self.profiles.first?.id
                return
            }
            let next = self.profiles[(index + 1) % self.profiles.count]
            self.activateProfile(id: next.id)
        }
    }

    /// First profile linked to the given application bundle identifier.
    func profile(forApp bundleID: String) -> Profile? {
        profiles.first { $0.linkedAppBundleIDs.contains(bundleID) }
    }

    // MARK: - Helpers

    /// Runs `work` synchronously when already on the main thread, otherwise
    /// dispatches it asynchronously — keeps every `@Published` mutation on main.
    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
