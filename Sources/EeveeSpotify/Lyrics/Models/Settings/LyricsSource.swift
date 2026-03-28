import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case lrclib = 0
    case musixmatch = 1
    case genius = 2
    case petit = 3
    case notReplaced = 4
    
    public static var allCases: [LyricsSource] {
        return [.lrclib, .musixmatch, .genius, .petit, .notReplaced]
    }

    var description: String {
        switch self {
        case .genius:
            return "Genius"
        case .lrclib:
            return "LRCLIB"
        case .musixmatch:
            return "Musixmatch"
        case .petit:
            return "PetitLyrics"
        case .notReplaced:
            return "Spotify"
        }
    }
    
    var isReplacingLyrics: Bool { self != .notReplaced }
    
    static var defaultSource: LyricsSource {
        .lrclib
    }
}
