//
//  FilterView.swift
//  app ch3
//
//  Filter view with glass morphism effect and advanced options
//

import SwiftUI

struct FilterView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @Binding var isPresented: Bool
    
    @State private var maxDistance: Double = UserDefaultsManager.shared.maxDistanceFilter ?? 100
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
                        // Distance Filter Section (simplified - just slider)
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
                    .foregroundColor(.white)
                Text("Distance")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(maxDistance)) km")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "a855f7"))
            }
            
            // Just the slider bar
            Slider(value: $maxDistance, in: 1...200, step: 1)
                .tint(Color(hex: "a855f7"))
            
            HStack {
                Text("1 km")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("200 km")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
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
                
                if !viewModel.selectedCategoryGroups.isEmpty {
                    Text("\(viewModel.selectedCategoryGroups.count) selected")
                        .font(.caption)
                        .foregroundColor(.appAccent)
                }
            }
            
            // Macro-category grid (2 columns)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CategoryGroup.allCases) { group in
                    MacroCategoryButton(
                        group: group,
                        isSelected: viewModel.selectedCategoryGroups.contains(group),
                        action: { viewModel.toggleCategoryGroup(group) }
                    )
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
        UserDefaultsManager.shared.maxDistanceFilter = maxDistance
        UserDefaultsManager.shared.showOnlyUnvisited = showOnlyUnvisited
        viewModel.applyFilters(
            sortOrder: sortOrder,
            maxDistance: maxDistance,
            showOnlyUnvisited: showOnlyUnvisited
        )
        withAnimation(.spring(response: 0.3)) {
            isPresented = false
        }
    }
    
    private func resetFilters() {
        sortOrder = .distance
        maxDistance = 200  // Max distance = show all
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

// MARK: - Macro Category Button

struct MacroCategoryButton: View {
    let group: CategoryGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .font(.system(size: 16))
                Text(group.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? group.color : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? group.color : Color.white.opacity(0.2), lineWidth: 1)
            )
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
    FilterView(viewModel: PlacesViewModel(), isPresented: .constant(true))
}

