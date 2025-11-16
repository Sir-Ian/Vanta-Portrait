//
//  Vanta_PortraitApp.swift
//  Vanta Portrait
//
//  Created by Ian Deuberry on 11/15/25.
//

import SwiftUI

@main
struct Vanta_PortraitApp: App {
    init() {
        let desc = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String ?? "nil"
        print("[Debug] NSCameraUsageDescription:", desc)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

