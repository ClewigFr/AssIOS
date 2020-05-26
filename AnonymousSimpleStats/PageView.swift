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

    var asJson: [String: Any] {
        return ["page": page.uuidString,
                "sessionId": sessionId.uuidString,
                "timestamp": "\(UInt64(timestamp * 1000))"]
    }
}

struct PageViews {
    var pageViews: [PageView]

    var asJson: [String: Any] {
        let views = pageViews.map({ $0.asJson })
        return ["pageViews": views]
    }
}
