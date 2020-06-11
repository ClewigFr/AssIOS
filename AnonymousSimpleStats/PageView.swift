//
//  PageView.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 26/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import Foundation

struct PageView: Equatable {
    var page: UUID
    var sessionId: UUID
    var timestamp: TimeInterval
    var pageName: String?

    // TODO: get ids and page names from config

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

    /// Turns object in json.
    /// Note: Send timestamp as delta time between hit and WS call
    var asJson: [String: Any] {
        return ["page": page.uuidString,
                "sessionId": sessionId.uuidString,
                "timestamp": "\(UInt64(Date().timeIntervalSince1970 - timestamp) * 1000)"] // in milliseconds
    }
}

struct PageViews {
    private(set) var pages: [PageView]

    var asJson: [String: Any] {
        let views = pages.map({ $0.asJson })
        return ["pageViews": views]
    }

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
