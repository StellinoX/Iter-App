//
//  TripsView.swift
//  app ch3
//
//  View to display saved trip itineraries
//

import SwiftUI

struct TripsView: View {
    @State private var savedTrips: [Trip] = []
    @State private var selectedTrip: Trip?
    @State private var showingTripDetail = false
    @State private var showingTripPlanner = false
    @Binding var isPresented: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Next trip (if any)
                if let nextTrip = savedTrips.first {
                    nextTripCard(nextTrip)
                }
                
                // Create new trip CTA
                createTripButton
                
                // Past trips
                if savedTrips.count > 1 {
                    pastTripsSection
                }
                
                // Empty state
                if savedTrips.isEmpty {
                    emptyState
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .background(Color.appBackground)
        .onAppear {
            loadSavedTrips()
        }
        .fullScreenCover(isPresented: $showingTripPlanner) {
            TripPlannerView(isPresented: $showingTripPlanner)
        }
        .sheet(isPresented: $showingTripDetail) {
            if let trip = selectedTrip {
                NavigationStack {
                    TripDetailView(trip: trip, isPresented: $showingTripDetail)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Trips")
                .font(.title.weight(.bold))
                .foregroundColor(.white)
            
            Text("Plan and manage your adventures")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }
    
    private func nextTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with "Next Trip" badge
            HStack {
                Text("🗓️ NEXT TRIP")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.appAccent)
                Spacer()
                Text(daysUntil(trip.startDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Trip info
            VStack(alignment: .leading, spacing: 8) {
                Text(trip.cityName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    Label(formatDateRange(trip.startDate, trip.endDate), systemImage: "calendar")
                    Label("\(trip.numberOfDays) days", systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                // Activities count
                let totalActivities = trip.days.reduce(0) { $0 + $1.activities.count }
                Text("\(totalActivities) places to visit")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
            
            // View button
            Button {
                selectedTrip = trip
                showingTripDetail = true
            } label: {
                Text("View Itinerary")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
            }
        }
        .background(Color(.systemGray6).opacity(0.4))
        .cornerRadius(20)
    }
    
    private var createTripButton: some View {
        Button {
            showingTripPlanner = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Plan a New Trip")
                    .font(.headline)
            }
            .foregroundColor(.appAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent.opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var pastTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Trips")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(savedTrips.dropFirst()) { trip in
                Button {
                    selectedTrip = trip
                    showingTripDetail = true
                } label: {
                    HStack(spacing: 12) {
                        // City icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Text("🏙️")
                                .font(.title2)
                        }
                        
                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.cityName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                            
                            Text(formatDateRange(trip.startDate, trip.endDate))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No trips planned yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Start planning your next adventure!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helpers
    
    private func loadSavedTrips() {
        // Load from UserDefaults
        // For now, use mock data or load from persistence
        savedTrips = UserDefaultsManager.shared.getSavedTrips()
    }
    
    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "Tomorrow"
        } else if days > 0 {
            return "In \(days) days"
        } else {
            return "Now"
        }
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    NavigationStack {
        TripsView(isPresented: .constant(true))
    }
}
