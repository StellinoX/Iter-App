//
//  NotificationManager.swift
//  app ch3
//
//  Manages push notifications for nearby hidden places
//

import Foundation
import UserNotifications
import CoreLocation
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isEnabled = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isEnabled = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Nearby Place Notification
    
    func scheduleNearbyPlaceNotification(place: Place, distance: Double) {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🗺️ Hidden Gem Nearby!"
        content.body = "You're \(Int(distance))m from \(place.displayName). Tap to explore!"
        content.sound = .default
        content.userInfo = ["placeId": place.id]
        
        // Badge
        content.badge = 1
        
        // Unique identifier for this place
        let identifier = "nearby-\(place.id)"
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Scheduled notification for \(place.displayName)")
            }
        }
    }
    
    // MARK: - Trip Reminder Notification
    
    func scheduleTripReminder(trip: Trip) {
        guard isEnabled else { return }
        
        // Schedule notification 1 day before trip
        let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: trip.startDate)!
        
        // Only schedule if in the future
        guard reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "✈️ Trip Tomorrow!"
        content.body = "Your \(trip.cityName) adventure starts tomorrow. Ready to explore?"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "trip-reminder-\(trip.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule trip reminder: \(error)")
            } else {
                print("✅ Scheduled reminder for \(trip.cityName)")
            }
        }
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
