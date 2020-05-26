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

        if let page = UUID(uuidString: "4e23d119-b282-4170-a820-928cd097bf36") {
            AnonymousSimpleStatsManager.shared.logScreen(page: page)
        }
    }
}
