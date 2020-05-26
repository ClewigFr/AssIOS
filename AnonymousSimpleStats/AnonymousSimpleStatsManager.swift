//
//  ASSManager.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import Foundation

public typealias AnonymousManager = AnonymousSimpleStatsManager

/// Anonymous Simple Stats Manager.

public class AnonymousSimpleStatsManager {

    // MARK: - Public Properties
    public static var shared = AnonymousSimpleStatsManager()

    // MARK: - Private Properties
    private let sessionID: UUID
    private let url: URL
    private var verbose: Bool

    // MARK: - Init
    private init() {
        self.verbose = false
        self.sessionID = UUID()
        self.url = URL(string: "https://gentle-inlet-02091.herokuapp.com/pages")!
    }

    // MARK: - Public Funcs

    /// Setup manager.
    public func setup(verbose: Bool = true) {
        self.verbose = verbose
        if verbose {
            print("AnonymousSimpleStatsManager: setup")
        }
    }

    /// Log screen.
    ///
    /// - Parameters:
    ///     - page: page id
    public func logScreen(page: UUID) {
        if verbose {
            print("AnonymousSimpleStatsManager: log screen")
        }
        let pageView = PageView(page: page,
                                sessionId: sessionID,
                                timestamp: Date().timeIntervalSince1970)
        let pageViews = PageViews(pageViews: [pageView])
        self.sendPages(pageViews)
    }
}

// MARK: - Private Funcs
private extension AnonymousSimpleStatsManager {
    /// Send pages.
    ///
    /// - Parameters:
    ///     - pageViews: PageViews
    func sendPages(_ pageViews: PageViews) {
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let data = try JSONSerialization.data(withJSONObject: pageViews.asJson,
                                                  options: .prettyPrinted)
            request.httpBody = data
            if verbose {
                print(String(bytes: data, encoding: .utf8) ?? "no json")
            }
        } catch let error {
            if verbose {
                print(error.localizedDescription)
            }
        }

        let task = session.dataTask(with: request as URLRequest,
                                    completionHandler: { [weak self] _, response, error in
                                        guard self?.verbose == true
                                            else { return }

                                        guard error == nil,
                                            let httpResponse = response as? HTTPURLResponse
                                            else {
                                                print(error?.localizedDescription ?? "error")
                                                return
                                        }
                                        switch httpResponse.statusCode {
                                        case 200:
                                            print("OK")
                                        case 206:
                                            print("Partial OK")
                                        default:
                                            print("error \(httpResponse.statusCode)")
                                        }
        })
        task.resume()
    }
}
