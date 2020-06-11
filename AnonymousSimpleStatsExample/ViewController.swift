//
//  ViewController.swift
//  AnonymousSimpleStatsExample
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import UIKit
import AnonymousSimpleStats

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add event to the page view stack.
        self.logScreen()

        // This log will be skipped (to close in time to the first one).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            self.logScreen()
        })

        // This log will be added to the stack.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
            self.logScreen()
        })
    }

    func logScreen() {
        // Log screen example with dedicated page id.
        // Page : iOS lib demo, id: 9a9e65d6-8c01-48e3-a487-2b6d1fd2967d
        AnonymousSimpleStatsManager.shared.logScreen(pageId: "9a9e65d6-8c01-48e3-a487-2b6d1fd2967d")
    }
}
