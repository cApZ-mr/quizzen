//
//  Log.swift
//  IOS - Quizzen
//

import OSLog

/// Zentraler Logger statt `print`. In Console.app nach dem Subsystem
/// (Bundle-ID) filterbar; funktioniert ohne `import OSLog` in jeder Datei.
nonisolated struct AppLog: Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Quizzen", category: "app")

    func debug(_ message: String)  { logger.debug("\(message, privacy: .public)") }
    func info(_ message: String)   { logger.info("\(message, privacy: .public)") }
    func notice(_ message: String) { logger.notice("\(message, privacy: .public)") }
    func error(_ message: String)  { logger.error("\(message, privacy: .public)") }
}

nonisolated let log = AppLog()
