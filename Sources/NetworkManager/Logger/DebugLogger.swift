//
//  DebugLogger.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 07/02/25.
//

import Foundation

internal class DebugLogger: @unchecked Sendable {
    internal static let shared = DebugLogger(isLoggingEnabled: true)
    
    private var isLoggingEnabled: Bool
    
    private init(isLoggingEnabled: Bool) {
        self.isLoggingEnabled = isLoggingEnabled
    }
    
    public func enableLogging(_ isEnabled: Bool) {
        self.isLoggingEnabled = isEnabled
    }
    
    internal func log(_ message: String, data: Data? = nil, level: LogLevel = .info, function: String = #function, file: String = #file, line: Int = #line) {
        guard isLoggingEnabled else { return } // Si logging está deshabilitado, no imprime nada
        var logEntry: [String: Any] = [
            "level": level.rawValue,
            "file": (file as NSString).lastPathComponent,
            "line": line,
            "function": function,
            "message": message,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let data = data {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                logEntry["data"] = jsonObject
            } catch {
                logEntry["data"] = "⚠️ Error decoding Data: \(error.localizedDescription)"
            }
        }

        // Convertimos el log a JSON para imprimirlo en formato legible
        if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

public enum LogLevel: String {
    case info = "✅ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

