import Foundation

enum MemexDateFormatting {
    static func displayDate(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func displayTime(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return date.formatted(.dateTime.hour().minute().second())
    }

    private static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
