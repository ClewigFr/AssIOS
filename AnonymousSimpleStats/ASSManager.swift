//
//  ASSManager.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import Foundation

public typealias ASSManager = AnonymousSimpleStatsManager

/// Anonymous Simple Stats Manager.
public class AnonymousSimpleStatsManager {

    // MARK: - Public Properties
    public static var shared = AnonymousSimpleStatsManager()

    // MARK: - Init
    private init() {}

    // MARK: - Public Funcs

    /// Setup manager.
    public func setup() {
        print("AnonymousSimpleStatsManager: setup")
    }

    /// Log screen.
    public func logScreen() {
        print("AnonymousSimpleStatsManager: log screen")
    }
}
