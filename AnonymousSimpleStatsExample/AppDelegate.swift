//
//  AppDelegate.swift
//  AnonymousSimpleStatsExample
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import UIKit
import AnonymousSimpleStats

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        AnonymousSimpleStatsManager.shared.setup()

        return true
    }
}
