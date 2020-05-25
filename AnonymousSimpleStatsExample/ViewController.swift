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

        AnonymousSimpleStatsManager.shared.logScreen()
    }
}
