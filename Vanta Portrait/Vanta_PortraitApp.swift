//
//  Vanta_PortraitApp.swift
//  Vanta Portrait
//
//  Created by Ian Deuberry on 11/15/25.
//

import SwiftUI
import Network

@main
struct Vanta_PortraitApp: App {
    init() {
        #if DEBUG
        let desc = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String ?? "nil"
        print("[Debug] NSCameraUsageDescription:", desc)
        debugNetworkPreflight()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    #if DEBUG
    private func debugNetworkPreflight() {
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        let platform = ProcessInfo.processInfo.operatingSystemVersionString
        print("[Debug] Sandbox: \(isSandboxed ? "enabled" : "unknown/disabled"), Platform: \(platform)")

        let host = "aistudio-foundry-east-us-2.cognitiveservices.azure.com"
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 443, using: .tls)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[Debug] DNS/connection to \(host): ready")
                connection.cancel()
            case .failed(let error):
                print("[Debug] DNS/connection to \(host) failed: \(error) — possible sandbox/network permission issue")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global())
    }
    #endif
}
