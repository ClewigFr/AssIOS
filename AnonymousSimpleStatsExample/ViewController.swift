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

        // Log screen example with dedicated page id.
        // Page : iOS lib demo, id: 9a9e65d6-8c01-48e3-a487-2b6d1fd2967d
        AnonymousSimpleStatsManager.shared.logScreen(pageId: "9a9e65d6-8c01-48e3-a487-2b6d1fd2967d")
    }
}
