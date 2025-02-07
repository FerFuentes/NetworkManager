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
    
    internal func log(_ message: String, level: LogLevel = .info, function: String = #function, file: String = #file, line: Int = #line) {
        guard isLoggingEnabled else { return } // Si logging está deshabilitado, no imprime nada
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - \(message)"
        print(logMessage)
    }
}

public enum LogLevel: String {
    case info = "✅ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

