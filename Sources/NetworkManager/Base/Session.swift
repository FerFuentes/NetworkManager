//
//  Session.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 07/02/25.
//

import Foundation
import Network

public class Session: @unchecked Sendable {
    public static let shared = Session()
    public internal(set) var debugMode: Bool?
    public internal(set) var host: String?
    public internal(set) var authenticationHeader: [String: String]?
    
    private init() {}
    
    internal lazy var session: URLSession = {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 20
        sessionConfiguration.httpAdditionalHeaders = authenticationHeader
        sessionConfiguration.sessionSendsLaunchEvents = false
        
        DebugLogger.shared.log(
            "Session created with: Host: \(host ?? "N/A"), AuthenticationHeader: \(authenticationHeader?.isEmpty ?? false) DebugMode: \(debugMode ?? false ? "ON" : "OFF")"
            , level: .info
        )
        return URLSession(configuration: sessionConfiguration)
    }()
    
    public func setHost(_ host: String) {
        self.host = host
    }
    
    public func setAuthenticationHeder(_ authHeader: [String: String]?) {
        authenticationHeader = authHeader
    }
    
    public func setDebugMode(_ debugMode: Bool) {
        self.debugMode = debugMode
    }

}
