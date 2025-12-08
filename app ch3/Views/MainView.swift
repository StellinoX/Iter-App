//
//  MainView.swift
//  app ch3
//
//  Vista principale con TabView per mappa e lista
//

import SwiftUI
import MapKit

struct MainView: View {
    @StateObject private var viewModel = PlacesViewModel()
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedTab = 0
    @State private var selectedPlace: Place?
    @State private var showingDetail = false
    @State private var showingFilters = false
    @State private var showingCitySearch = false
    @State private var showingTripPlanner = false
    @State private var showingListView = false
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "Home"
        case 1: return "Map"
        case 2: return "Your Trips"
        case 3: return "Favorites"
        case 4: return "Statistics"
        default: return "Home"
        }
    }
    
    var body: some View {
        contentView
            .tint(Color.appAccent)
            .sheet(isPresented: $showingDetail) {
                detailSheet
            }
            .sheet(isPresented: $showingCitySearch) {
                citySearchSheet
            }
            .fullScreenCover(isPresented: $showingTripPlanner) {
                TripPlannerView(isPresented: $showingTripPlanner)
            }
    }
    
    private var contentView: some View {
        NavigationStack {
            mainTabView
                .tint(Color.appAccent)
                .if(selectedTab == 0 || selectedTab == 1) { view in
                    view.searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search secret places..."
                    )
                    .onSubmit(of: .search) {
                        Task {
                            await viewModel.performGlobalSearch()
                        }
                    }
                }
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .overlay {
                    filterOverlay
                }
                .task {
                    setupLocation()
                }
        }
    }
    
    private func setupLocation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        } else if locationManager.location == nil {
            locationManager.startUpdating()
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Only show toolbar buttons on Map (tab 1)
        if selectedTab == 1 {
            ToolbarItem(placement: .navigationBarLeading) {
                filtersButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                citySearchButton
            }
        }
    }
    
    @ViewBuilder
    private var detailSheet: some View {
        if let place = selectedPlace {
            PlaceDetailView(place: place, userLocation: locationManager.location, viewModel: viewModel)
        }
    }
    
    private var citySearchSheet: some View {
        CitySearchView(isPresented: $showingCitySearch) { region, cityName in
            viewModel.navigateToRegion(region)
            selectedTab = 1 // Switch to map
        }
    }
    
    // MARK: - Subviews
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            homeTab
            mapTab
            tripsTab
            favoritesTab
            statsTab
        }
    }
    
    private var homeTab: some View {
        HomeView(
            viewModel: viewModel,
            userLocation: locationManager.location,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail,
            onPlanTrip: { showingTripPlanner = true }
        )
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(0)
    }
    
    private var mapTab: some View {
        ImprovedMapView(
            viewModel: viewModel,
            locationManager: locationManager,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail
        )
        .tabItem {
            Label("Map", systemImage: "map.fill")
        }
        .tag(1)
    }
    
    private var tripsTab: some View {
        TripsView(isPresented: .constant(true))
            .tabItem {
                Label("Trips", systemImage: "airplane")
            }
            .tag(2)
    }
    
    private var favoritesTab: some View {
        FavoritesView(
            viewModel: viewModel,
            userLocation: locationManager.location,
            selectedPlace: $selectedPlace,
            showingDetail: $showingDetail
        )
        .tabItem {
            Label("Favorites", systemImage: "heart.fill")
        }
        .tag(3)
    }
    
    private var statsTab: some View {
        StatisticsView(viewModel: viewModel)
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(4)
    }
    
    @ViewBuilder
    private var filterOverlay: some View {
        if showingFilters {
            FilterView(viewModel: viewModel)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showingFilters = false
                    }
                }
        }
    }
    
    private var filtersButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingFilters.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body)
                Text("Filters")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.appAccent)
        }
    }
    
    private var citySearchButton: some View {
        Button {
            showingCitySearch = true
        } label: {
            Image(systemName: "location.magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundColor(.appAccent)
        }
    }
}

#Preview {
    MainView()
}
