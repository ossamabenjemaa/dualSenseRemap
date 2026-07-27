import Foundation
import AppKit

/// Errors thrown by `HammerspoonBridge.installSpoon()`.
/// User-facing descriptions are in French (UI language of the app).
enum HammerspoonBridgeError: LocalizedError {
    case spoonSourceNotFound
    case installFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .spoonSourceNotFound:
            return "Le dossier « DualSenseRemap.spoon » est introuvable dans les ressources de l'application."
        case .installFailed(let underlying):
            return "L'installation du Spoon a échoué : \(underlying.localizedDescription)"
        }
    }
}

/// Bridge to Hammerspoon via its `hammerspoon://` URL scheme.
///
/// Trigger URL shape (must match `Hammerspoon/DualSenseRemap.spoon/init.lua`,
/// which binds the URL event "dsr"):
///
///     hammerspoon://dsr?event=NAME&key=value
///
/// The event name is carried as a query parameter — the URL host is the
/// Hammerspoon URL-event name, and Hammerspoon requires that no path be
/// present in the URL. `trigger` returns `false` when Hammerspoon is not
/// installed so callers can fall back to a native implementation.
final class HammerspoonBridge {

    static let shared = HammerspoonBridge()

    /// Hammerspoon's bundle identifier.
    private static let hammerspoonBundleID = "org.hammerspoon.Hammerspoon"

    /// URL event name bound by the Spoon (`hs.urlevent.bind("dsr", …)`).
    private static let urlEventHost = "dsr"

    /// Identical events posted within this window are swallowed (button
    /// repeat storms would otherwise spam `NSWorkspace.open`).
    private static let debounceInterval: TimeInterval = 0.05

    /// Optional override for the location of the `DualSenseRemap.spoon`
    /// source directory (used by `installSpoon()`). When nil, well-known
    /// locations are probed — the app bundle resources first, then the
    /// repository layout for developer builds.
    var spoonSourcePath: URL?

    private let debounceLock = NSLock()
    private var lastTriggerKey = ""
    private var lastTriggerTime: TimeInterval = 0

    private init() {}

    /// True when Hammerspoon.app is present on this Mac (findable through
    /// Launch Services or at the conventional /Applications path).
    var isInstalled: Bool {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.hammerspoonBundleID) != nil {
            return true
        }
        return FileManager.default.fileExists(atPath: "/Applications/Hammerspoon.app")
    }

    /// Fires a Spoon event through the URL scheme, without activating
    /// Hammerspoon. Returns `false` when Hammerspoon is not installed —
    /// the caller should then run its native fallback.
    @discardableResult
    func trigger(_ event: String, params: [String: String]) -> Bool {
        guard isInstalled else { return false }

        var components = URLComponents()
        components.scheme = "hammerspoon"
        components.host = Self.urlEventHost // event name; no path allowed
        var queryItems = [URLQueryItem(name: "event", value: event)]
        for (key, value) in params.sorted(by: { $0.key < $1.key }) {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return false }

        // Debounce identical triggers (repeat storms).
        let key = url.absoluteString
        let now = ProcessInfo.processInfo.systemUptime
        debounceLock.lock()
        let isDuplicate = (key == lastTriggerKey) && (now - lastTriggerTime < Self.debounceInterval)
        if !isDuplicate {
            lastTriggerKey = key
            lastTriggerTime = now
        }
        debounceLock.unlock()
        if isDuplicate { return true }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false // never let Hammerspoon steal focus
        NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)
        return true
    }

    /// The three lines the user must add to `~/.hammerspoon/init.lua`.
    static let initLuaSnippet = """
    require("hs.ipc")
    hs.loadSpoon("DualSenseRemap")
    spoon.DualSenseRemap:start()
    """

    /// Copies the bundled `DualSenseRemap.spoon` directory into
    /// `~/.hammerspoon/Spoons/` (replacing any previous version) and returns
    /// the Lua snippet the user must add to their `init.lua`.
    @discardableResult
    func installSpoon() throws -> String {
        guard let source = resolveSpoonSource() else {
            throw HammerspoonBridgeError.spoonSourceNotFound
        }

        let fileManager = FileManager.default
        let spoonsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".hammerspoon", isDirectory: true)
            .appendingPathComponent("Spoons", isDirectory: true)
        let destination = spoonsDirectory.appendingPathComponent("DualSenseRemap.spoon", isDirectory: true)

        do {
            try fileManager.createDirectory(at: spoonsDirectory,
                                            withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw HammerspoonBridgeError.installFailed(underlying: error)
        }

        return Self.initLuaSnippet
    }

    /// Locates the `DualSenseRemap.spoon` source directory.
    private func resolveSpoonSource() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let override = spoonSourcePath {
            candidates.append(override)
        }
        // Bundled resource (production .app layout).
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("DualSenseRemap.spoon", isDirectory: true))
        }
        // Developer builds: binary next to the repository checkout.
        let repoRelative = ["Hammerspoon/DualSenseRemap.spoon"]
        for relative in repoRelative {
            candidates.append(URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(relative, isDirectory: true))
            candidates.append(Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(relative, isDirectory: true))
        }

        var isDirectory: ObjCBool = false
        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        return nil
    }
}
