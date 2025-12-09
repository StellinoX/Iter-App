//
//  app_ch3App.swift
//  app ch3
//
//  Created by Alfonso Giuseppe Auriemma on 02/12/25.
//

import SwiftUI

@main
struct app_ch3App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some View {
        if hasCompletedOnboarding {
            MainView()
        } else {
            OnboardingView(isCompleted: $hasCompletedOnboarding)
        }
    }
}
