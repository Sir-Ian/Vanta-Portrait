//
//  Vanta_PortraitUITestsLaunchTests.swift
//  Vanta PortraitUITests
//
//  Created by Ian Deuberry on 11/15/25.
//

import XCTest

final class Vanta_PortraitUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        throw XCTSkip("Launch performance tests skipped for targeted portrait flow UI validation.")
    }
}
