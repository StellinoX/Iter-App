//
//  SettingsView.swift
//  app ch3
//
//  App settings including notification preferences
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var notificationsEnabled = false
    @State private var showingNotificationAlert = false
    
    var body: some View {
        List {
            // Notifications Section
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.appAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nearby Place Alerts")
                                .foregroundColor(.white)
                            Text("Get notified when near hidden gems")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .tint(.appAccent)
                .onChange(of: notificationsEnabled) { _, newValue in
                    handleNotificationToggle(newValue)
                }
            } header: {
                Text("Notifications")
            }
            
            // App Info Section
            Section {
                HStack {
                    Text("Version")
                        .foregroundColor(.white)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } header: {
                Text("About")
            }
            
            // Data Section
            Section {
                Button {
                    resetOnboarding()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                        Text("Reset Onboarding")
                            .foregroundColor(.white)
                    }
                }
                
                Button(role: .destructive) {
                    clearAllData()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Data")
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Clearing data will remove all saved trips, favorites, and visited places.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "0f0720"))
        
        .onAppear {
            notificationsEnabled = notificationManager.isEnabled
        }
        .alert("Enable Notifications", isPresented: $showingNotificationAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                notificationsEnabled = false
            }
        } message: {
            Text("Please enable notifications in Settings to receive nearby place alerts.")
        }
    }
    
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await notificationManager.requestAuthorization()
                await MainActor.run {
                    if !granted {
                        showingNotificationAlert = true
                    }
                    notificationsEnabled = granted
                    UserDefaults.standard.set(granted, forKey: "proximityNotificationsEnabled")
                }
            }
        } else {
            UserDefaults.standard.set(false, forKey: "proximityNotificationsEnabled")
        }
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    private func clearAllData() {
        // Clear trips
        UserDefaultsManager.shared.saveSavedTrips([])
        // Clear favorites
        UserDefaultsManager.shared.saveFavorites([])
        // Clear visited
        UserDefaultsManager.shared.saveVisited([])
        // Clear notifications
        NotificationManager.shared.clearAllNotifications()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
