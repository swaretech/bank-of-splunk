import Foundation

struct LoginResponse: Codable {
    let token: String
    let name: String
    let user: String
    let accountId: String

    enum CodingKeys: String, CodingKey {
        case token
        case name
        case user
        case accountId = "account_id"
    }
}

struct Contact: Codable, Identifiable, Hashable {
    var id: String { accountNum }
    let accountNum: String
    let routingNum: String
    let label: String?
    let isExternal: Bool

    enum CodingKeys: String, CodingKey {
        case accountNum = "account_num"
        case routingNum = "routing_num"
        case label
        case isExternal = "is_external"
    }

    var displayLabel: String {
        label ?? accountNum
    }
}

struct Transaction: Codable, Identifiable, Hashable {
    var id: String {
        "\(timestamp)-\(fromAccountNum)-\(toAccountNum)-\(amount)"
    }

    let timestamp: String
    let fromAccountNum: String
    let toAccountNum: String
    let amount: Int
    let accountLabel: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case fromAccountNum
        case toAccountNum
        case amount
        case accountLabel
    }
}

struct HomeData: Codable {
    let accountId: String
    let name: String
    let username: String
    let balance: Int
    let history: [Transaction]
    let contacts: [Contact]
    let bankName: String
    let localRoutingNum: String

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
        case username
        case balance
        case history
        case contacts
        case bankName = "bank_name"
        case localRoutingNum = "local_routing_num"
    }
}

struct MessageResponse: Codable {
    let message: String
}

struct APIErrorResponse: Codable {
    let error: String
}

enum CurrencyFormatter {
    static func format(cents: Int?) -> String {
        guard let cents else { return "$---" }
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$---"
    }
}

enum TransactionFormatter {
    static func day(from timestamp: String) -> String {
        guard let date = parseDate(timestamp) else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    static func month(from timestamp: String) -> String {
        guard let date = parseDate(timestamp) else { return "---" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private static func parseDate(_ timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }
}
