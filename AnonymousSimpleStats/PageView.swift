//
//  PageView.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 26/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import Foundation

struct PageView {
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

    /// Turns object in json.
    /// Note: Send timestamp as delta time between hit and WS call
    var asJson: [String: Any] {
        return ["page": page.uuidString,
                "sessionId": sessionId.uuidString,
                "timestamp": "\(UInt64(Date().timeIntervalSince1970 - timestamp))"]
    }
}

struct PageViews {
    var pages: [PageView]

    var asJson: [String: Any] {
        let views = pages.map({ $0.asJson })
        return ["pageViews": views]
    }

    var hasContent: Bool {
        return pages.isEmpty == false
    }
}
