//
//  EmptyResponse.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 27/02/25.
//

import Foundation

public struct EmptyResponse: Codable {
    static var instance: EmptyResponse {
        return EmptyResponse()
    }
}
