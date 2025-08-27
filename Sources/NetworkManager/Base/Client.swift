//
//  Client.swift
//  NetworkManager
//
//  Created by Fernando Fuentes on 03/12/24.
//
import Foundation
import Network

public protocol Client {
    func sendRequest<T: Decodable>(
        endpoint: Base,
        responseModel: T.Type
    ) async -> Result<T, RequestError>

    func sendRequest<T: Decodable>(
        delegate: URLSessionDelegate,
        endpoint: Base, responseModel: T.Type
    ) async

    func getModelFromLocation<T: Decodable>(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        location: URL,
        responseModel: T.Type
    ) -> Result<T, RequestError>
}

extension Client {
    public func sendRequest<T: Decodable>(
        endpoint: Base,
        responseModel: T.Type
    ) async -> Result<T, RequestError> {
        guard let url = buildURL(from: endpoint) else {
            return .failure(.invalidURL)
        }

        do {
            let request = buildRequest(for: endpoint, url: url)
            let session = try await createSession(from: endpoint)
            let (data, response) = try await session.data(for: request)
            session.finishTasksAndInvalidate()

            return await handleResponse(
                response, data: data,
                responseModel: responseModel,
                request: request,
                endpoint: endpoint,
                debugMode: endpoint.debugMode ?? false
            )

        } catch let error as NSError {
            return handleError(error)
        } catch {
            return .failure(.unknown)
        }
    }
    
}

extension Client {
    public func sendRequest<T: Decodable>(
        delegate: URLSessionDelegate,
        endpoint: Base,
        responseModel: T.Type
    ) async {
        let logger = DebugLogger.shared
        logger.enableLogging(endpoint.debugMode ?? false)

        guard let url = buildURL(from: endpoint) else {
            return
        }

        let request = buildRequest(for: endpoint, url: url)
        logger.log("Request", data: request.httpBody, level: .info)
        let backgroundSession = await createSession(
            from: endpoint,
            delegate: delegate,
            identifier: endpoint.backgroundSessionIdentifier ?? "unknown"
        )
        
        backgroundSession.downloadTask(with: request).resume()
    }
    
}

extension Client {
    
    public func getModelFromLocation<T: Decodable>(_ session: URLSession, downloadTask: URLSessionDownloadTask, location: URL, responseModel: T.Type)  -> Result<T, RequestError> {
        guard let response = downloadTask.response as? HTTPURLResponse,
                let data = try? Data(contentsOf: location) else {
            return .failure(.noResponse)
        }

        session.finishTasksAndInvalidate()

        return handleResponse(
            response,
            location: data,
            responseModel: responseModel,
            debugMode: true
        )
    }
}
