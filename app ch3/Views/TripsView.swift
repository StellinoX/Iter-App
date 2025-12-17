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
    @State private var isEditMode = false
    @State private var selectedForDeletion: Set<UUID> = []
    @Binding var isPresented: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Edit button
                headerSection
                
                // Plan Your Adventure CTA
                planAdventureCTA
                
                // All trips (uniform cards)
                if !savedTrips.isEmpty {
                    allTripsSection
                }
                
                // Empty state
                if savedTrips.isEmpty {
                    emptyState
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .background(Color(hex: "0f0720"))
        .onAppear {
            loadSavedTrips()
        }
        .fullScreenCover(isPresented: $showingTripPlanner, onDismiss: {
            loadSavedTrips()
        }) {
            TripPlannerView(isPresented: $showingTripPlanner)
        }
        .sheet(isPresented: $showingTripDetail) {
            if let trip = selectedTrip {
                NavigationStack {
                    TripDetailView(trip: trip, isPresented: $showingTripDetail, isPlanning: false)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            Text("Your Adventures")
                .font(.title.weight(.bold))
                .foregroundColor(.white)
            
            Spacer()
            
            if !savedTrips.isEmpty {
                Button {
                    withAnimation {
                        if isEditMode && !selectedForDeletion.isEmpty {
                            deleteSelectedTrips()
                        }
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedForDeletion.removeAll()
                        }
                    }
                } label: {
                    Text(isEditMode ? (selectedForDeletion.isEmpty ? "Done" : "Delete") : "Edit")
                        .foregroundColor(isEditMode && !selectedForDeletion.isEmpty ? .red : .white)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // Plan Your Adventure CTA with green gradient
    private var planAdventureCTA: some View {
        Button {
            showingTripPlanner = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Your Adventure")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text("Get AI-powered itineraries")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "9FE000"), Color(hex: "6BBF00")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
        }
    }
    
    // All trips in uniform cards
    private var allTripsSection: some View {
        VStack(spacing: 12) {
            ForEach(savedTrips) { trip in
                tripCard(trip)
            }
        }
    }
    
    // Uniform trip card
    private func tripCard(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            // Edit mode checkbox
            if isEditMode {
                Button {
                    if selectedForDeletion.contains(trip.id) {
                        selectedForDeletion.remove(trip.id)
                    } else {
                        selectedForDeletion.insert(trip.id)
                    }
                } label: {
                    Image(systemName: selectedForDeletion.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedForDeletion.contains(trip.id) ? .red : .white.opacity(0.5))
                        .font(.title2)
                }
            }
            
            // Trip content
            Button {
                if !isEditMode {
                    selectedTrip = trip
                    showingTripDetail = true
                }
            } label: {
                HStack(spacing: 12) {
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.cityName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        
                        Text(formatDateRange(trip.startDate, trip.endDate))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if !isEditMode {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(isEditMode)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "suitcase")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No adventures planned yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Start planning your next adventure!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helpers
    
    private func loadSavedTrips() {
        savedTrips = UserDefaultsManager.shared.getSavedTrips()
    }
    
    private func deleteSelectedTrips() {
        savedTrips.removeAll { selectedForDeletion.contains($0.id) }
        UserDefaultsManager.shared.saveSavedTrips(savedTrips)
        selectedForDeletion.removeAll()
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
