//
//  JuniorGlobeApp.swift
//  JuniorGlobe
//
//  Created by 薛宜安 on 2026/3/26.
//

import SwiftUI

@main
struct JuniorGlobeApp: App {
    init() {
        RevenueCatBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
