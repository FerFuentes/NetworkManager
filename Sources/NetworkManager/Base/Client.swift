//
//  Client.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 03/12/24.
//
import Foundation
import Network

public protocol Client {
    func sendRequest<T: Decodable>(endpoint: Base, responseModel: T.Type) async -> Result<T, RequestError>
    func sendRequest<T: Decodable>(delegate: URLSessionDelegate, identifier: String, endpoint: Base, responseModel: T.Type)
    func getModelFromLocation<T: Decodable>(_ session: URLSession, downloadTask: URLSessionDownloadTask, location: URL, responseModel: T.Type) -> Result<T, RequestError>
}

extension Client {
    public func sendRequest<T: Decodable>(
        endpoint: Base,
        responseModel: T.Type
    ) async -> Result<T, RequestError> {
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.version + endpoint.path
        urlComponents.queryItems = endpoint.parameters
        let logger = DebugLogger.shared
        logger.enableLogging(endpoint.debugMode ?? false)
        
        guard let url = urlComponents.url else {
            return .failure(.invalidURL)
        }
        
        do {
            
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.allHTTPHeaderFields = endpoint.header
            
            if let body = endpoint.body {
                request.httpBody = body
            }

            let (data, response) = try await endpoint.sessionConfiguration.session.data(for: request)
            
            guard let response = response as? HTTPURLResponse else {
                return .failure(.noResponse)
            }
            
            logger.log("Status code: \(response.statusCode)", data: request.httpBody, level: .info)
            
            switch response.statusCode {
                
            case 200...299:
                do {
                    let decodedResponse = try JSONDecoder().decode(responseModel, from: data)
                    logger.log("Response", data: data, level: .info)
                    
                    return .success(decodedResponse)
                } catch {
                    logger.log("Decode error: \(error.localizedDescription)", level: .error)
                    return .failure(.unexpectedError(error.localizedDescription))
                }
            case 400:
                do {
                    let decodedResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    let message = decodedResponse.message
                    logger.log("Error Response:", data: data, level: .error)
                    return .failure(.badRequest(message))
                } catch {
                    logger.log("Decode error: \(error.localizedDescription)", level: .error)
                    return .failure(.unexpectedError(error.localizedDescription))
                }
                
            case 401:
                logger.log("Unauthorized", level: .error)
                return .failure(.unauthorized)
                
            default:
                logger.log("Unexpected StatusCode: \(response.statusCode)", level: .error)
                return .failure(.unexpectedStatusCode("We are unable to retrieve your information at this time, please try again later."))
            }
        } catch let error as NSError {
            
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
    
}

extension Client {
    public func sendRequest<T: Decodable>(
        delegate: URLSessionDelegate,
        identifier: String,
        endpoint: Base,
        responseModel: T.Type
    ) {
        let logger = DebugLogger.shared
        logger.enableLogging(endpoint.debugMode ?? false)
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.version + endpoint.path
        urlComponents.queryItems = endpoint.parameters
        
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 20
        sessionConfiguration.isDiscretionary = false
        
        guard let url = urlComponents.url
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.header
        
        if let body = endpoint.body {
            request.httpBody = body
        }
        logger.log("[Client-Background] Request: \(request)", level: .info)
        let backgroundSession = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        backgroundSession.downloadTask(with: request).resume()
        
    }
    
}

extension Client {
    
    public func getModelFromLocation<T: Decodable>(_ session: URLSession, downloadTask: URLSessionDownloadTask, location: URL, responseModel: T.Type) -> Result<T, RequestError> {
        let logger = DebugLogger.shared
        logger.enableLogging(true)
        
        guard let response = downloadTask.response as? HTTPURLResponse else {
            session.invalidateAndCancel()
            return .failure(.noResponse)
        }
        
        session.finishTasksAndInvalidate()
        switch response.statusCode {
            
        case 200...299:
            
            do {
                let data = try Data(contentsOf: location)
                let decodedResponse = try JSONDecoder().decode(responseModel, from: data)
                logger.log("[Client-Background] Response: \(decodedResponse)", level: .info)
                return .success(decodedResponse)
            } catch {
                logger.log("[Client-Background] Decode error: \(error.localizedDescription)", level: .error)
                return .failure(.unexpectedError(error.localizedDescription))
            }
            
        case 400:
            do {
                let data = try Data(contentsOf: location)
                let decodedResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                let message = decodedResponse.message
                logger.log("[Client-Background] Error Response: \(decodedResponse)", level: .error)
                return .failure(.badRequest(message))
            } catch {
                logger.log("[Client-Background] Decode error: \(error.localizedDescription)", level: .error)
                return .failure(.unexpectedError(error.localizedDescription))
            }
            
        case 401:
            return .failure(.unauthorized)
            
        default:
            logger.log("[Client-Background] Unexpected StatusCode: \(response.statusCode)", level: .error)
            return .failure(.unexpectedStatusCode("We are unable to retrieve your information at this time, please try again later."))
        }
    }

}
