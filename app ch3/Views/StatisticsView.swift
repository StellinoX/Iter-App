//
//  StatisticsView.swift
//  app ch3
//
//  Personal statistics dashboard showing exploration progress
//

import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: PlacesViewModel
    
    // Near You stats - based on places visible on map
    private var nearbyPlacesCount: Int {
        viewModel.places.count
    }
    
    private var nearbyVisitedCount: Int {
        viewModel.places.filter { viewModel.visitedIDs.contains($0.id) }.count
    }
    
    private var nearbyCompletionPercentage: Double {
        guard nearbyPlacesCount > 0 else { return 0 }
        return Double(nearbyVisitedCount) / Double(nearbyPlacesCount) * 100
    }
    
    // Global totals
    private var visitedCount: Int {
        viewModel.visitedIDs.count
    }
    
    private var favoriteCount: Int {
        viewModel.favoriteIDs.count
    }
    
    private var categoryBreakdown: [(String, Int)] {
        // Use city categories if available
        if !viewModel.cityCountByCategory.isEmpty {
            return viewModel.cityCountByCategory.sorted { $0.value > $1.value }
        }
        var counts: [String: Int] = [:]
        for place in viewModel.places {
            if let category = place.categoryName {
                counts[category, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    private var visitedCategories: [(String, Int)] {
        var counts: [String: Int] = [:]
        for place in viewModel.places where viewModel.isVisited(place.id) {
            if let category = place.categoryName {
                counts[category, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Global/Regional Stats
                regionalStatsSection
                
                // Local/Nearby Progress Ring
                progressSection
                
                // Quick Stats (your totals)
                quickStatsSection
                
                // Category Breakdown
                categorySection
                
                // Achievements
                achievementsSection
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.fetchDistinctValues()
            await viewModel.fetchRegionalStats()
        }
    }
    
    // MARK: - Regional Stats Section
    
    private var regionalStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🌍 Global Statistics")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                RegionCard(
                    icon: "globe",
                    title: "World",
                    total: viewModel.regionalStats.worldTotal,
                    visited: viewModel.visitedIDs.count,
                    color: .blue
                )
                
                RegionCard(
                    icon: "building.columns.fill",
                    title: "Europe",
                    total: viewModel.regionalStats.europeTotal,
                    visited: 0, // Will calculate
                    color: .green
                )
                
                RegionCard(
                    icon: "mountain.2.fill",
                    title: "Americas",
                    total: viewModel.regionalStats.americasTotal,
                    visited: 0,
                    color: .orange
                )
                
                RegionCard(
                    icon: "flag.fill",
                    title: "Asia & Russia",
                    total: viewModel.regionalStats.asiaTotal,
                    visited: 0,
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
    
    // MARK: - Subviews
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Color.appAccent)
                Text("Near You")
                    .font(.headline)
                    .foregroundColor(.white)
                if let city = viewModel.currentCity {
                    Text("• \(city)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 160, height: 160)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: nearbyCompletionPercentage / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appVisited],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: nearbyCompletionPercentage)
                
                // Center text
                VStack(spacing: 4) {
                    Text("\(Int(nearbyCompletionPercentage))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(nearbyVisitedCount)/\(nearbyPlacesCount)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Text("Places explored in view")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "mappin.circle.fill",
                value: "\(nearbyPlacesCount)",
                label: "In View",
                color: .blue
            )
            
            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(visitedCount)",
                label: "Visited",
                color: .appVisited
            )
            
            StatCard(
                icon: "heart.fill",
                value: "\(favoriteCount)",
                label: "Favorites",
                color: .red
            )
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("By Category")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(categoryBreakdown.count) categories")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if categoryBreakdown.isEmpty {
                Text("No categories yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(categoryBreakdown.prefix(5), id: \.0) { category, count in
                    HStack {
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.appAccent)
                                    .frame(width: geo.size.width * (Double(count) / Double(max(1, nearbyPlacesCount))), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(width: 100, height: 8)
                        
                        Text("\(count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appAccent)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AchievementBadge(
                    icon: "star.fill",
                    title: "Explorer",
                    description: "Visit 10 places",
                    isUnlocked: visitedCount >= 10,
                    progress: min(Double(visitedCount) / 10, 1)
                )
                
                AchievementBadge(
                    icon: "heart.fill",
                    title: "Collector",
                    description: "Save 5 favorites",
                    isUnlocked: favoriteCount >= 5,
                    progress: min(Double(favoriteCount) / 5, 1)
                )
                
                AchievementBadge(
                    icon: "map.fill",
                    title: "Adventurer",
                    description: "Visit 25 places",
                    isUnlocked: visitedCount >= 25,
                    progress: min(Double(visitedCount) / 25, 1)
                )
                
                AchievementBadge(
                    icon: "crown.fill",
                    title: "Master",
                    description: "Visit 50 places",
                    isUnlocked: visitedCount >= 50,
                    progress: min(Double(visitedCount) / 50, 1)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.appAccent : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if !isUnlocked {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.appAccent, lineWidth: 3)
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isUnlocked ? .black : .gray)
            }
            
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isUnlocked ? .white : .gray)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.2))
        .cornerRadius(12)
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

// MARK: - Region Card

struct RegionCard: View {
    let icon: String
    let title: String
    let total: Int
    let visited: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(visited) / Double(total) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(total)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(visited) visited")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(viewModel: PlacesViewModel())
    }
}
