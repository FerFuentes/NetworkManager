//
//  ClientConfiguration.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 26/08/25.
//

import Foundation
import Network

extension Client {
    internal func buildURL(from endpoint: Base) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.version + endpoint.path
        urlComponents.queryItems = endpoint.parameters
        return urlComponents.url
    }

    internal func buildRequest(for endpoint: Base, url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.header

        if let body = endpoint.body {
            request.httpBody = body
        }
        return request
    }

    internal func createSession(
        from endpoint: Base
    ) async throws -> URLSession {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 20
        sessionConfiguration.sessionSendsLaunchEvents = false

        if let authenticationHeders = try? await endpoint.authenticationHeders {
            sessionConfiguration.httpAdditionalHeaders = authenticationHeders
        }
        return URLSession(configuration: sessionConfiguration)
    }

    internal func handleResponse<T: Decodable>(
        _ response: URLResponse,
        data: Data,
        responseModel: T.Type,
        request: URLRequest,
        endpoint: Base,
        debugMode: Bool = false
    ) async -> Result<T, RequestError> {
        let logger = DebugLogger.shared
        logger.enableLogging(debugMode)

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.noResponse)
        }

        let urlString = request.url?.absoluteString.isEmpty == false
            ? request.url!.absoluteString
            : "Unknown URL"

        logger.log(
            "Request: \(urlString), Status Code: \(httpResponse.statusCode)",
            data: request.httpBody,
            level: .info
        )


        switch httpResponse.statusCode {


        case 200...299:
            return decodeSuccessResponse(
                data: data,
                responseModel: responseModel,
                debugMode: debugMode
            )
        case 401:
            logger.log("Unauthorized", level: .error)
            if let callback = endpoint.onAuthenticationChallenge {
                do {
                    try await callback()
                } catch {
                    logger.log("Error executing authentication callback: \(error.localizedDescription)", level: .error)
                }
            }

            return .failure(.unauthorized)
        default:
            return decodeErrorResponse(
                data: data,
                debugMode: debugMode
            )
        }

    }

    internal func decodeSuccessResponse<T: Decodable>(data: Data, responseModel: T.Type, debugMode: Bool = false) -> Result<T, RequestError> {
        let logger = DebugLogger.shared
        logger.enableLogging(debugMode)

        if T.self == EmptyResponse.self {
            guard let emptyResponse = EmptyResponse.instance as? T else {
                return .failure(.decode)
            }
            return .success(emptyResponse)
        } else {
            do {
                let decodedResponse = try JSONDecoder().decode(responseModel, from: data)
                logger.log("Response", data: data, level: .info)
                return .success(decodedResponse)
            } catch {
                logger.log("Decode error: \(error.localizedDescription)", level: .error)
                return .failure(.unexpectedError(error.localizedDescription))
            }
        }
    }

    internal func decodeErrorResponse<T>(data: Data, debugMode: Bool = false) -> Result<T, RequestError> {
        let logger = DebugLogger.shared
        logger.enableLogging(debugMode)

        do {
            let decodedResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = decodedResponse.message
            logger.log("Error Response:", data: data, level: .error)
            return .failure(.badRequest(message))
        } catch {
            logger.log("Decode error: \(error.localizedDescription)", level: .error)
            return .failure(.unexpectedError(error.localizedDescription))
        }
    }

    internal func handleError<T>(_ error: NSError) -> Result<T, RequestError> {
        switch error.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut:
            return .failure(.internetConnection(error.localizedDescription))
        default:
            return .failure(.unknown)
        }
    }

}

// MARK: - Background Configuration
extension Client {
    internal func createSession(
        from endpoint: Base,
        delegate: URLSessionDelegate,
        identifier: String
    ) async -> URLSession {
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfiguration.timeoutIntervalForRequest = 15
        sessionConfiguration.timeoutIntervalForResource = 15
        sessionConfiguration.isDiscretionary = false
        sessionConfiguration.sessionSendsLaunchEvents = true

        if let authenticationHeders = try? await endpoint.authenticationHeders {
            sessionConfiguration.httpAdditionalHeaders = authenticationHeders
        }

        return URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
    }

    func handleResponse<T: Decodable>(
            _ response: URLResponse,
            location: Data,
            responseModel: T.Type,
            debugMode: Bool = false
    ) -> Result<T, RequestError> {
        let logger = DebugLogger.shared
        logger.enableLogging(debugMode)

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.noResponse)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return decodeSuccessResponse(
                data: location,
                responseModel: responseModel,
                debugMode: debugMode
            )
        case 401:
            return .failure(.unauthorized)
        case 404:
            return decodeErrorResponse(
                data: location,
                debugMode: debugMode
            )
        default:
            logger.log("Unexpected StatusCode: \(httpResponse.statusCode)", level: .error)
            return .failure(.unexpectedStatusCode("We are unable to retrieve your information at this time, please try again later."))
        }
    }
}
