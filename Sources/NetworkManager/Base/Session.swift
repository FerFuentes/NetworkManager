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
    public internal(set) var authenticationHeader: [String: String]?
    
    private init() {}
    
    internal lazy var session: URLSession = {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 20
        sessionConfiguration.httpAdditionalHeaders = authenticationHeader
        sessionConfiguration.sessionSendsLaunchEvents = false
        return URLSession(configuration: sessionConfiguration)
    }()
    
    public func setAuthenticationData(authHeader: [String: String]?) {
        authenticationHeader = authHeader
    }
}
