//
//  AnonymousSimpleStatsTests.swift
//  AnonymousSimpleStatsTests
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import XCTest
@testable import AnonymousSimpleStats

class AnonymousSimpleStatsTests: XCTestCase {

    override func setUpWithError() throws {
        AnonymousSimpleStatsManager.shared.setup()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
