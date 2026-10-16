import Foundation

enum PlayerCommand: String, CaseIterable, Sendable {
    case toggle, previous, next, show, menu
    case seek0, seek10, seek20, seek30, seek40, seek50, seek60, seek70, seek80, seek90, seek100

    var seekPercent: Int? {
        guard rawValue.hasPrefix("seek") else { return nil }
        return Int(rawValue.dropFirst(4))
    }
    static var seekSteps: [Self] { allCases.filter { $0.seekPercent != nil } }
}
