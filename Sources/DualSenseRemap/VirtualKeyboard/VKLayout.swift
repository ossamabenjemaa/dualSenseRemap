import Foundation

// MARK: - Shift state

/// Shift state of the virtual keyboard, mirroring the PS5 on-screen keyboard:
/// one-shot uppercase (auto-clears after one letter) and caps lock.
enum VKShiftState: Equatable {
    case off
    case once
    case caps

    var isActive: Bool { self != .off }
}

// MARK: - Special keys

/// Non-character keys of the keyboard grid.
enum VKSpecial: Hashable {
    case shift
    case backspace
    case space
    case enter
    case layerABC
    case layerSymbols
    case layerAccents
    case cursorLeft
    case cursorRight
    case options
    case controllerHint
    case done
}

// MARK: - Key model

/// One key of the virtual keyboard grid.
struct VKKey: Identifiable, Hashable {
    enum Kind: Hashable {
        /// (lowercase, uppercase) pair — shift picks the variant.
        case character(String, String)
        /// Fixed symbol, unaffected by shift.
        case symbol(String)
        case special(VKSpecial)
    }

    let id: String
    let kind: Kind
    var widthUnits: Double = 1
    /// Controller badge token rendered as a small chip: "L1", "R1", "L2",
    /// "R2", "R3", "L3+R3", or the tokens "triangle" / "square" which the
    /// view renders as SF Symbols.
    var controllerBadge: String? = nil
    /// Optional label override (used by the symbols page-flip key "1/2"/"2/2").
    var labelOverride: String? = nil

    var special: VKSpecial? {
        if case .special(let s) = kind { return s }
        return nil
    }

    /// Keys that auto-repeat while ✕ is held.
    var isRepeatable: Bool {
        switch special {
        case .backspace, .space, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    /// Display label for the current shift state.
    func display(shift: VKShiftState) -> String {
        if let labelOverride { return labelOverride }
        switch kind {
        case .character(let lower, let upper):
            return shift.isActive ? upper : lower
        case .symbol(let s):
            return s
        case .special(let sp):
            switch sp {
            case .shift: return "⇧"
            case .backspace: return "⌫"
            case .space: return ""
            case .enter: return "⏎"
            case .layerABC: return "ABC"
            case .layerSymbols: return "@#:"
            case .layerAccents: return "à"
            case .cursorLeft: return "◀"
            case .cursorRight: return "▶"
            case .options: return "•••"
            case .controllerHint: return ""
            case .done: return "OK"
            }
        }
    }
}

// MARK: - Pages

/// A full keyboard grid: 4 character rows + function row + bottom row.
typealias VKPage = [[VKKey]]

enum VKPageID: Equatable {
    case letters
    case symbols1
    case symbols2
    case accents
}

/// Focus coordinates in the grid (row index, column index).
struct VKPosition: Hashable {
    var row: Int
    var col: Int
}

// MARK: - Layout definition

/// Static layout of the PS5-style AZERTY keyboard (see
/// docs/research/ps5-keyboard-hammerspoon.md, sections A.2–A.6).
enum VKLayout {

    // MARK: Builders

    private static func ch(_ lower: String, _ upper: String) -> VKKey {
        VKKey(id: "ch-\(lower)", kind: .character(lower, upper))
    }

    private static func sym(_ s: String) -> VKKey {
        VKKey(id: "sym-\(s)", kind: .symbol(s))
    }

    // MARK: Invariant function rows

    /// Row 4 — mirrors the PS5 bottom function bar:
    /// [⇧ L2] [ABC] [@#:] [à R3] [space △] [⌫ □]
    static let functionRow: [VKKey] = [
        VKKey(id: "fn-shift", kind: .special(.shift), widthUnits: 1.5, controllerBadge: "L2"),
        VKKey(id: "fn-abc", kind: .special(.layerABC), widthUnits: 1.25),
        VKKey(id: "fn-symbols", kind: .special(.layerSymbols), widthUnits: 1.25),
        VKKey(id: "fn-accents", kind: .special(.layerAccents), widthUnits: 1.25, controllerBadge: "R3"),
        VKKey(id: "fn-space", kind: .special(.space), widthUnits: 4.25, controllerBadge: "triangle"),
        VKKey(id: "fn-backspace", kind: .special(.backspace), widthUnits: 1.5, controllerBadge: "square"),
    ]

    /// Row 5 — [◀ L1] [▶ R1] [•••] [🎮 L3+R3] [OK R2]
    static let bottomRow: [VKKey] = [
        VKKey(id: "bt-cursor-left", kind: .special(.cursorLeft), widthUnits: 1.5, controllerBadge: "L1"),
        VKKey(id: "bt-cursor-right", kind: .special(.cursorRight), widthUnits: 1.5, controllerBadge: "R1"),
        VKKey(id: "bt-options", kind: .special(.options), widthUnits: 2),
        VKKey(id: "bt-hint", kind: .special(.controllerHint), widthUnits: 2, controllerBadge: "L3+R3"),
        VKKey(id: "bt-done", kind: .special(.done), widthUnits: 4, controllerBadge: "R2"),
    ]

    // MARK: Character rows — AZERTY letters

    private static let lettersRows: [[VKKey]] = [
        [sym("1"), sym("2"), sym("3"), sym("4"), sym("5"), sym("6"),
         sym("7"), sym("8"), sym("9"), sym("0"), sym("@")],
        [ch("a", "A"), ch("z", "Z"), ch("e", "E"), ch("r", "R"), ch("t", "T"), ch("y", "Y"),
         ch("u", "U"), ch("i", "I"), ch("o", "O"), ch("p", "P"), sym("#")],
        [ch("q", "Q"), ch("s", "S"), ch("d", "D"), ch("f", "F"), ch("g", "G"), ch("h", "H"),
         ch("j", "J"), ch("k", "K"), ch("l", "L"), ch("m", "M"), sym("/")],
        [ch("w", "W"), ch("x", "X"), ch("c", "C"), ch("v", "V"), ch("b", "B"), ch("n", "N"),
         sym("'"), sym("-"), sym("_"), sym("?"), sym("!")],
    ]

    // MARK: Character rows — symbols page 1/2

    private static let symbols1Rows: [[VKKey]] = [
        [sym("€"), sym("$"), sym("£"), sym("¥"), sym("%"), sym("&"),
         sym("*"), sym("("), sym(")"), sym("["), sym("]")],
        [sym("@"), sym("#"), sym(":"), sym(";"), sym("\""), sym("'"),
         sym("`"), sym("^"), sym("~"), sym("|"), sym("\\")],
        [sym("+"), sym("-"), sym("×"), sym("÷"), sym("="), sym("<"),
         sym(">"), sym("{"), sym("}"), sym("°"), sym("§")],
        [sym("!"), sym("?"), sym("/"), sym("_"), sym(","), sym("."),
         sym("…"), sym("«"), sym("»"), sym("¿"),
         VKKey(id: "sym-page-2", kind: .special(.layerSymbols), labelOverride: "2/2")],
    ]

    // MARK: Character rows — symbols page 2/2

    private static let symbols2Rows: [[VKKey]] = [
        [sym("¹"), sym("²"), sym("³"), sym("¼"), sym("½"), sym("¾"),
         sym("±"), sym("µ"), sym("‰"), sym("¢"), sym("¤")],
        [sym("‘"), sym("’"), sym("“"), sym("”"), sym("‚"), sym("„"),
         sym("‹"), sym("›"), sym("–"), sym("—"), sym("•")],
        [sym("©"), sym("®"), sym("™"), sym("†"), sym("‡"), sym("¶"),
         sym("≈"), sym("≠"), sym("≤"), sym("≥"), sym("∞")],
        [sym("·"), sym("¨"), sym("´"), sym("¸"), sym("ª"), sym("º"),
         sym("¦"), sym("¬"), sym("⁄"), sym("‾"),
         VKKey(id: "sym-page-1", kind: .special(.layerSymbols), labelOverride: "1/2")],
    ]

    // MARK: Character rows — accents (full French set, lower + upper visible)

    private static let accentsRows: [[VKKey]] = [
        [sym("à"), sym("â"), sym("ä"), sym("é"), sym("è"), sym("ê"),
         sym("ë"), sym("î"), sym("ï"), sym("ô"), sym("ö")],
        [sym("ù"), sym("û"), sym("ü"), sym("ç"), sym("œ"), sym("æ"),
         sym("ÿ"), sym("«"), sym("»"), sym("’"), sym("€")],
        [sym("À"), sym("Â"), sym("Ä"), sym("É"), sym("È"), sym("Ê"),
         sym("Ë"), sym("Î"), sym("Ï"), sym("Ô"), sym("Ö")],
        [sym("Ù"), sym("Û"), sym("Ü"), sym("Ç"), sym("Œ"), sym("Æ"),
         sym("Ÿ"), sym("‘"), sym("”"), sym("“"), sym("°")],
    ]

    // MARK: Assembled pages

    static let lettersPage: VKPage = lettersRows + [functionRow, bottomRow]
    static let symbols1Page: VKPage = symbols1Rows + [functionRow, bottomRow]
    static let symbols2Page: VKPage = symbols2Rows + [functionRow, bottomRow]
    static let accentsPage: VKPage = accentsRows + [functionRow, bottomRow]

    static func page(_ id: VKPageID) -> VKPage {
        switch id {
        case .letters: return lettersPage
        case .symbols1: return symbols1Page
        case .symbols2: return symbols2Page
        case .accents: return accentsPage
        }
    }

    // MARK: Geometry helpers (unit space, for nearest-column navigation)

    /// Horizontal center (in width units) of the key at `col` in `row`.
    static func center(ofCol col: Int, inRow row: [VKKey]) -> Double {
        var x = 0.0
        for i in 0..<col { x += row[i].widthUnits }
        return x + row[col].widthUnits / 2
    }

    /// Index of the key whose center is nearest to `target` (in width units).
    static func nearestCol(toCenter target: Double, inRow row: [VKKey]) -> Int {
        var best = 0
        var bestDistance = Double.greatestFiniteMagnitude
        var x = 0.0
        for (i, key) in row.enumerated() {
            let center = x + key.widthUnits / 2
            let distance = abs(center - target)
            if distance < bestDistance {
                bestDistance = distance
                best = i
            }
            x += key.widthUnits
        }
        return best
    }
}
