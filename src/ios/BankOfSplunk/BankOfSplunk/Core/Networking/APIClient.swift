import Foundation

enum APIClientError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .unauthorized:
            return "Invalid username or password."
        case .serverError(let message):
            return message
        case .decodingFailed:
            return "Unable to read server response."
        case .network(let error):
            return error.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        try await post(path: "/api/v1/login", body: [
            "username": username,
            "password": password,
        ], token: nil)
    }

    func signup(payload: [String: String]) async throws -> LoginResponse {
        try await post(path: "/api/v1/signup", body: payload, token: nil, expectedStatus: 201)
    }

    func logout(token: String) async throws {
        _ = try await request(path: "/api/v1/logout", method: "POST", token: token)
    }

    func fetchHome(token: String) async throws -> HomeData {
        try await get(path: "/api/v1/home", token: token)
    }

    func deposit(token: String, payload: [String: Any]) async throws -> String {
        let response: MessageResponse = try await post(path: "/api/v1/deposit", body: payload, token: token)
        return response.message
    }

    func payment(token: String, payload: [String: Any]) async throws -> String {
        let response: MessageResponse = try await post(path: "/api/v1/payment", body: payload, token: token)
        return response.message
    }

    private func get<T: Decodable>(path: String, token: String?) async throws -> T {
        let data = try await request(path: path, method: "GET", token: token)
        return try decode(data)
    }

    private func post<T: Decodable>(
        path: String,
        body: [String: Any],
        token: String?,
        expectedStatus: Int = 200
    ) async throws -> T {
        let data = try await request(
            path: path,
            method: "POST",
            token: token,
            body: body,
            expectedStatus: expectedStatus
        )
        return try decode(data)
    }

    private func request(
        path: String,
        method: String,
        token: String?,
        body: [String: Any]? = nil,
        expectedStatus: Int = 200
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: AppConfig.apiBaseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIClientError.decodingFailed
            }

            if http.statusCode == 401 {
                throw APIClientError.unauthorized
            }

            if http.statusCode == 204 {
                return Data()
            }

            if http.statusCode != expectedStatus {
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    throw APIClientError.serverError(apiError.error)
                }
                throw APIClientError.serverError("Request failed with status \(http.statusCode)")
            }

            return data
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.network(error)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        guard !data.isEmpty else {
            throw APIClientError.decodingFailed
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }
}
