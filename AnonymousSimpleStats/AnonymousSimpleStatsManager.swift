//
//  ASSManager.swift
//  AnonymousSimpleStats
//
//  Created by Clement Picot on 25/05/2020.
//  Copyright © 2020 Clewig. All rights reserved.
//

import UIKit

public typealias AnonymousManager = AnonymousSimpleStatsManager

/// Anonymous Simple Stats Manager.

public class AnonymousSimpleStatsManager {

    // MARK: - Public Properties
    public static var shared = AnonymousManager()

    // MARK: - Private Properties
    private let sessionID: UUID
    private let url: URL
    private var verbose: Bool
    private var pagesStack: PageViews

    // MARK: - Private Enums
    private enum Constants {
        static let minPageStacKBeforeSend: Int = 2
        static let minHitDeltaTimeBeforeSend: TimeInterval = 4.0
        // TODO: Move this string elsewhere
        static let backEndUrl: String = "https://gentle-inlet-02091.herokuapp.com/views"
    }

    // MARK: - Init
    private init() {
        self.verbose = false
        self.sessionID = UUID()
        self.pagesStack = PageViews(pages: [])
        self.url = URL(string: Constants.backEndUrl)!

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    // MARK: - Public Funcs

    /// Setup manager.
    public func setup(verbose: Bool = false) {
        self.verbose = verbose
        if verbose {
            print("AnonymousSimpleStats: setup")
        }
    }

    /// Log screen.
    ///
    /// - Parameters:
    ///     - page: page id String
    public func logScreen(pageId: String) {
        guard let page = UUID(uuidString: pageId)
            else { return }

        let pageView = PageView(page: page,
                                sessionId: sessionID)
        if verbose {
            print("AnonymousSimpleStats: log page \(pageView.pageName ?? "")")
        }
        self.stackPage(pageView)
    }
}

// MARK: - Event Handling Funcs
private extension AnonymousManager {
    /// Send stacked pages when user leave app.
    @objc func applicationWillResignActive() {
        if self.pagesStack.hasContent {
            self.sendPages(pagesStack)
        }
    }
}

// MARK: - Private Funcs
private extension AnonymousManager {
    /// Return true if page(s) can be sent.
    /// Defines batch send rules
    func shouldSendStack() -> Bool {
        return self.pagesStack.pages.count >= Constants.minPageStacKBeforeSend
            && self.pagesStack.stackDeltaTime > Constants.minHitDeltaTimeBeforeSend
    }

    /// Stack page before sending.
    ///
    /// - Parameters:
    ///     - pageView: PageView to stack
    func stackPage(_ pageView: PageView) {
        self.pagesStack.appendPage(pageView)
        if self.shouldSendStack() {
            self.sendPages(pagesStack)
        }
    }

    /// Send pages to back end.
    ///
    /// - Parameters:
    ///     - pageViews: PageViews to send
    func sendPages(_ pageViews: PageViews) {
        // TODO: check network?
        if verbose {
            print("AnonymousSimpleStats: send \(pageViews.pages.count) page(s)")
        }
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
                print(String(bytes: data, encoding: .utf8) ?? "Error: No Json")
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
                                                if self?.verbose == true {
                                                    print(error?.localizedDescription ?? "error")
                                                }
                                                return
                                        }
                                        self?.handleResponseCode(httpResponse.statusCode)
        })
        task.resume()
    }

    func handleResponseCode(_ code: Int) {
        let message: String
        switch code {
        case 200:
            message = "Ok"
            self.pagesStack.reset()
        case 206:
            message = "Partially OK. Page id(s) should be checked."
            self.pagesStack.reset()
        case 400:
            message = "Back end JSON error: \(code)"
            self.pagesStack.reset()
        default:
            message = "Error: \(code)"
            // save + retry later
        }
        if self.verbose == true {
            print(message)
        }
    }
}
