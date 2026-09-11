import Foundation

public enum HTTPError: Error, Equatable {
    case invalidResponse
    case status(Int)
}

public struct HTTPClient: Sendable {
    public typealias Send = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let sendRequest: Send

    public init(send: @escaping Send) {
        self.sendRequest = send
    }

    public func send<Response: Decodable>(
        _ request: URLRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        let (data, response) = try await sendRequest(request)
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError.status(response.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    public static var live: Self {
        Self { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            return (data, response)
        }
    }
}
