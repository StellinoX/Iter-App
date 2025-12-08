//
//  FilterView.swift
//  app ch3
//
//  Filter view with glass morphism effect and advanced options
//

import SwiftUI

struct FilterView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var maxDistance: Double = UserDefaultsManager.shared.maxDistanceFilter ?? 100
    @State private var hasDistanceFilter: Bool = UserDefaultsManager.shared.maxDistanceFilter != nil
    @State private var sortOrder: SortOrder = UserDefaultsManager.shared.sortOrder
    @State private var showOnlyUnvisited: Bool = UserDefaultsManager.shared.showOnlyUnvisited
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background with blur effect
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    saveAndDismiss()
                }
            
            // Glass morphism card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Filters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Sort Order Section
                        sortSection
                        
                        divider
                        
                        // Distance Filter Section
                        distanceSection
                        
                        divider
                        
                        // Show Only Unvisited
                        unvisitedSection
                        
                        divider
                        
                        // Category Filters
                        categorySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                // Footer buttons
                footerButtons
            }
            .background(
                ZStack {
                    Color.appBackground.opacity(0.95)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 100)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Sections
    
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.appAccent)
                Text("Sort by")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 8) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: order.icon)
                            Text(order.displayName)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(sortOrder == order ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(sortOrder == order ? Color.appAccent : Color.white.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.appAccent)
                Text("Max Distance")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("", isOn: $hasDistanceFilter)
                    .tint(.appAccent)
                    .labelsHidden()
            }
            
            if hasDistanceFilter {
                VStack(spacing: 8) {
                    Slider(value: $maxDistance, in: 1...200, step: 1)
                        .tint(.appAccent)
                    
                    HStack {
                        Text("1 km")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(maxDistance)) km")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appAccent)
                        Spacer()
                        Text("200 km")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private var unvisitedSection: some View {
        HStack {
            Image(systemName: "eye.slash")
                .foregroundColor(.appAccent)
            Text("Show only unvisited")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $showOnlyUnvisited)
                .tint(.appAccent)
                .labelsHidden()
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.appAccent)
                Text("Categories")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !viewModel.selectedCategories.isEmpty {
                    Text("\(viewModel.selectedCategories.count) selected")
                        .font(.caption)
                        .foregroundColor(.appAccent)
                }
            }
            
            if viewModel.availableCategories.isEmpty {
                Text("No categories available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.availableCategories.sorted(), id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategories.contains(category),
                            action: { viewModel.toggleCategory(category) }
                        )
                    }
                }
            }
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
    }
    
    private var footerButtons: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                Button {
                    resetFilters()
                } label: {
                    Text("Reset All")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button {
                    saveAndDismiss()
                } label: {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appAccent)
                        .cornerRadius(12)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Actions
    
    private func saveAndDismiss() {
        UserDefaultsManager.shared.sortOrder = sortOrder
        UserDefaultsManager.shared.maxDistanceFilter = hasDistanceFilter ? maxDistance : nil
        UserDefaultsManager.shared.showOnlyUnvisited = showOnlyUnvisited
        viewModel.applyFilters(
            sortOrder: sortOrder,
            maxDistance: hasDistanceFilter ? maxDistance : nil,
            showOnlyUnvisited: showOnlyUnvisited
        )
        dismiss()
    }
    
    private func resetFilters() {
        sortOrder = .distance
        hasDistanceFilter = false
        maxDistance = 100
        showOnlyUnvisited = false
        viewModel.clearCategoryFilters()
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appAccent : Color.white.opacity(0.1))
                .cornerRadius(16)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    FilterView(viewModel: PlacesViewModel())
}

