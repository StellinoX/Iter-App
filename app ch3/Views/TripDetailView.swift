//
//  TripDetailView.swift
//  app ch3
//
//  Displays the generated trip itinerary with day-by-day tabs
//

import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @Binding var isPresented: Bool
    @State private var selectedDay = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Trip header
            tripHeader
            
            // Day tabs
            dayTabs
            
            // Activities for selected day
            ScrollView {
                if selectedDay < trip.days.count {
                    activitiesForDay(trip.days[selectedDay])
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(trip.cityName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveTrip()
                    isPresented = false
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.appAccent)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.appAccent)
                Text(dateRange)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text("\(trip.numberOfDays) days in \(trip.cityName)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
    }
    
    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(0..<trip.days.count), id: \.self) { index in
                    Button {
                        withAnimation {
                            selectedDay = index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Day \(index + 1)")
                                .font(.subheadline.weight(selectedDay == index ? .bold : .medium))
                            
                            Text(dayDateString(trip.days[index].date))
                                .font(.caption2)
                        }
                        .foregroundColor(selectedDay == index ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedDay == index ? Color(hex: "BFFF00") : Color(.systemGray6).opacity(0.3))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private func dayDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func activitiesForDay(_ day: TripDay) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(day.activities.enumerated()), id: \.element.id) { index, activity in
                VStack(spacing: 0) {
                    // Transport indicator (if not first)
                    if index > 0 {
                        transportIndicator(activity)
                    }
                    
                    // Activity card
                    activityCard(activity)
                    
                    // Lunch suggestions after this activity
                    if let lunch = day.lunchSuggestions, lunch.afterActivityIndex == index {
                        mealSuggestionSection(lunch, fromActivity: activity)
                    }
                    
                    // Dinner suggestions after this activity
                    if let dinner = day.dinnerSuggestions, dinner.afterActivityIndex == index {
                        mealSuggestionSection(dinner, fromActivity: activity)
                    }
                }
            }
        }
        .padding()
    }
    
    private func mealSuggestionSection(_ meal: MealSuggestion, fromActivity: TripActivity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal divider with type and time
            HStack(spacing: 8) {
                VStack {
                    Divider()
                        .frame(width: 2, height: 16)
                        .background(Color.orange.opacity(0.6))
                }
                .frame(width: 40)
                
                HStack(spacing: 6) {
                    Text(meal.mealType.emoji)
                    Text(meal.mealType.rawValue)
                        .font(.caption.weight(.medium))
                    Text(meal.mealType.suggestedTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.top, 12)
            
            // Restaurant cards
            ForEach(meal.restaurants) { restaurant in
                RestaurantSuggestionCard(restaurant: restaurant)
            }
        }
    }
    
    private func transportIndicator(_ activity: TripActivity) -> some View {
        HStack(spacing: 8) {
            VStack {
                Divider()
                    .frame(width: 2, height: 20)
                    .background(Color.gray.opacity(0.5))
            }
            .frame(width: 40)
            
            if let mode = activity.transportMode {
                HStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.caption)
                    if let duration = activity.transportDuration {
                        Text(duration)
                            .font(.caption2)
                    }
                    if let details = activity.transportDetails, !details.isEmpty {
                        Text("• \(details)")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.gray)
                .padding(.leading, 8)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func activityCard(_ activity: TripActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack {
                Text(activity.startTime)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appAccent)
                
                Text(activity.duration)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 40)
            
            // Activity details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.placeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                if let notes = activity.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Actions
            Button {
                // Open in maps
            } label: {
                Image(systemName: "map")
                    .foregroundColor(.appAccent)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func saveTrip() {
        // Save full trip to UserDefaults
        UserDefaultsManager.shared.saveTrip(trip)
    }
}

// MARK: - Restaurant Suggestion Card

struct RestaurantSuggestionCard: View {
    let restaurant: RestaurantSuggestion
    @State private var isAdded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Restaurant icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                Text("🍽️")
                    .font(.title2)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(restaurant.category)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(restaurant.formattedDistance)
                        .font(.caption)
                        .foregroundColor(.appAccent)
                }
            }
            
            Spacer()
            
            // Add button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isAdded.toggle()
                }
            } label: {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appAccent)
                        .font(.title2)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isAdded ? Color.appAccent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        TripDetailView(
            trip: Trip(cityName: "Roma", startDate: Date(), endDate: Date().addingTimeInterval(3*24*60*60)),
            isPresented: .constant(true)
        )
    }
}
