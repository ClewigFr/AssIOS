//
//  PageView.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 26/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import Foundation

// MARK: - PageView

struct PageView: Equatable {
    var page: UUID
    var sessionId: UUID
    var timestamp: TimeInterval
    var pageName: String?

    // TODO: get ids and page names from config

    init(page: UUID, sessionId: UUID, timestamp: TimeInterval, pageName: String? = nil) {
        self.page = page
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.pageName = pageName
    }

    init(page: UUID, sessionId: UUID, pageName: String? = nil) {
        self.page = page
        self.sessionId = sessionId
        self.timestamp = Date().timeIntervalSince1970
        self.pageName = pageName
    }

    static func == (lhs: PageView, rhs: PageView) -> Bool {
        return lhs.page == rhs.page
            && (rhs.timestamp - lhs.timestamp < 0.5 ) // same 1/2 second
    }
}

// MARK: serialization / deserialization

extension PageView {
    /// Turns object in json.
    /// Note: Send timestamp as delta time between hit and WS call
    var jsonExport: [String: Any] {
        return ["page": page.uuidString,
                "sessionId": sessionId.uuidString,
                "timestamp": "\(UInt64(Date().timeIntervalSince1970 - timestamp) * 1000)"] // in milliseconds
    }

    func toJson() -> [String: Any] {
        return ["page": page.uuidString,
                "sessionId": sessionId.uuidString,
                "timestamp": timestamp]
    }

    static func pageView(with jsonObject: [String: Any]) -> PageView? {
        guard let page = jsonObject["page"] as? String,
            let pageUUID = UUID(uuidString: page),
            let sessionId = jsonObject["sessionId"] as? String,
            let sessionIdUUID = UUID(uuidString: sessionId),
            let timestamp = jsonObject["timestamp"] as? TimeInterval
            else {
                return nil
        }
        return PageView(page: pageUUID, sessionId: sessionIdUUID, timestamp: timestamp)
    }

//    static func pageView(with jsonString: String) -> PageView? {
//        if let data = jsonString.data(using: .utf8) {
//            let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
//            if let dictionary = json as? [String: Any] {
//                return pageView(with: dictionary)
//            }
//        }
//        return nil
//    }
}

// MARK: - PageViews

struct PageViews {
    private(set) var pages: [PageView]

    var hasContent: Bool {
        return pages.isEmpty == false
    }

    var stackDeltaTime: TimeInterval {
        return (self.pages.last?.timestamp ?? 0.0) - (self.pages.first?.timestamp ?? 0.0)
    }

    mutating func appendPage(_ page: PageView) {
        // Check if event already exists befaore append (user bug, call in a loop, etc.)
        if pages.contains(where: { $0 == page }) == false {
            pages.append(page)
        } else {
            print("AnonymousSimpleStats: warning, skip duplicate page \(page.page) \(page.pageName ?? "")")
        }
    }

    mutating func reset() {
        pages.removeAll()
    }
}

// MARK: serialization / deserialization

extension PageViews {
    var jsonExport: [String: Any] {
        let views = pages.map({ $0.jsonExport })
        return ["pageViews": views]
    }

    func toJsonData() -> Data? {
        let views = pages.map({ $0.toJson() })
        guard !views.isEmpty
            else { return nil }

        let pages = ["pageViews": views]
        return try? JSONSerialization.data(withJSONObject: pages, options: .prettyPrinted)
    }

    static func pageViews(with jsonData: Data?) -> PageViews? {
        if let data = jsonData {
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            if let dictionary = json as? [String: Any],
                let pageViewsJson = dictionary["pageViews"] as? [[String: Any]] {
                var pageViews = PageViews(pages: [])
                pageViewsJson.forEach { (pageJson) in
                    if let pageView = PageView.pageView(with: pageJson) {
                        pageViews.appendPage(pageView)
                    }
                }
                return pageViews.hasContent ? pageViews : nil
            }
        }
        return nil
    }
}
