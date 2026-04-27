//
//  RSSFeedParser.swift
//  JuniorGlobe
//

import Foundation

struct ParsedFeedItem: Sendable {
    let title: String
    let summary: String
    let link: String
    let publishedAt: Date?
}

enum RSSFeedParserError: LocalizedError {
    case unreadableFeed

    var errorDescription: String? {
        switch self {
        case .unreadableFeed:
            return "無法解析新聞來源 feed。"
        }
    }
}

final class RSSFeedParser: NSObject {
    func parse(data: Data) throws -> [ParsedFeedItem] {
        let delegate = RSSXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? RSSFeedParserError.unreadableFeed
        }

        return delegate.items
    }
}

private final class RSSXMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var items: [ParsedFeedItem] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentUpdated = ""
    private var isInsideItem = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()

        if currentElement == "item" || currentElement == "entry" {
            isInsideItem = true
            currentTitle = ""
            currentSummary = ""
            currentLink = ""
            currentPubDate = ""
            currentUpdated = ""
        }

        if isInsideItem, currentElement == "link", let href = attributeDict["href"], href.isEmpty == false {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else {
            return
        }

        switch currentElement {
        case "title":
            currentTitle += string
        case "description", "summary", "content:encoded":
            currentSummary += string
        case "link":
            currentLink += string
        case "pubdate", "dc:date", "published":
            currentPubDate += string
        case "updated":
            currentUpdated += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard isInsideItem, let cdata = String(data: CDATABlock, encoding: .utf8) else {
            return
        }

        switch currentElement {
        case "description", "summary", "content:encoded":
            currentSummary += cdata
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let endedElement = elementName.lowercased()
        guard endedElement == "item" || endedElement == "entry" else {
            return
        }

        isInsideItem = false

        let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = currentSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)

        guard title.isEmpty == false, link.isEmpty == false else {
            return
        }

        items.append(
            ParsedFeedItem(
                title: title,
                summary: summary,
                link: link,
                publishedAt: RSSDateParser.parse(currentPubDate.isEmpty ? currentUpdated : currentPubDate)
            )
        )
    }
}

enum RSSDateParser {
    private static let formatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    static func parse(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}
