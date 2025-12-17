//
//  ImprovedMapView.swift
//  app ch3
//
//  Improved map with modern UI/UX
//

import SwiftUI
import MapKit



struct ImprovedMapView: View {
    @ObservedObject var viewModel: PlacesViewModel
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedPlace: Place?
    @Binding var showingDetail: Bool
    
    @Namespace private var mapScope
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lastUpdateTask: Task<Void, Never>?
    @State private var currentRegion: MKCoordinateRegion?
    @State private var showListView = false
    
    var body: some View {
        ZStack {
            if showListView {
                // List View
                PlacesListView(
                    viewModel: viewModel,
                    userLocation: locationManager.location,
                    selectedPlace: $selectedPlace,
                    showingDetail: $showingDetail
                )
            } else {
                // Map View
                mapContent
            }
            
            // Bottom buttons overlay - positioned just above tab bar
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // List/Map toggle button (centered)
                    listModalButton
                    
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    // Location button (right aligned, same level)
                    locationButton
                        .padding(.trailing, 16)
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    // Small rectangle list button
    private var listModalButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                showListView.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: showListView ? "map.fill" : "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
                Text(showListView ? "Map" : "List")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appAccent)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
    
    // Location button
    private var locationButton: some View {
        Button(action: {
            if let userLocation = locationManager.location {
                withAnimation(.spring(response: 0.6)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    ))
                }
            }
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(Color.appAccent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
    
    private var mapContent: some View {
        ZStack {
            // Mappa
            Map(position: $cameraPosition) {
                // Pin dell'utente con animazione
                if let userLocation = locationManager.location {
                    Annotation("You are here", coordinate: userLocation) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 40, height: 40)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                
                // Pin dei luoghi e cluster
                ForEach(viewModel.clusteredItems) { item in
                    switch item {
                    case .place(let place):
                        if let coordinate = place.coordinate {
                            Annotation(place.displayName, coordinate: coordinate) {
                                PlacePin(place: place, isVisited: viewModel.isVisited(place.id))
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedPlace = place
                                        }
                                    }
                            }
                            .annotationTitles(.hidden)
                        }
                        
                    case .cluster(let id, let coordinate, let places):
                        Annotation("Cluster \(id)", coordinate: coordinate) {
                            ClusterPin(count: places.count)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6)) {
                                        // Zoom in sul cluster
                                        let span = MKCoordinateSpan(
                                            latitudeDelta: (currentRegion?.span.latitudeDelta ?? 0.5) / 2.0,
                                            longitudeDelta: (currentRegion?.span.longitudeDelta ?? 0.5) / 2.0
                                        )
                                        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: span))
                                    }
                                }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapScope(mapScope)
            .mapControls {
                MapCompass(scope: mapScope)
            }
            
            .onMapCameraChange(frequency: .onEnd) { context in
                currentRegion = context.region
                
                // Aggiorna clustering
                viewModel.updateClusteredItems(for: context.region)
                
                lastUpdateTask?.cancel()
                
                lastUpdateTask = Task {
                    // Aumentato debounce a 700ms per ridurre chiamate API
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    
                    if !Task.isCancelled {
                        await viewModel.fetchPlacesInRegion(context.region)
                        // Aggiorna clustering con nuovi dati
                        viewModel.updateClusteredItems(for: context.region)
                        
                        // Detect city for statistics (with separate debounce)
                        await viewModel.detectCity(from: context.region.center)
                    }
                }
            }
            
            // Discrete loading indicator (non-blocking)
            if viewModel.isLoading {
                VStack {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Loading")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .allowsHitTesting(false) // Non blocca l'interazione con la mappa
            }
        }
        .task {
            if let userLocation = locationManager.location {
                let initialRegion = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
                withAnimation {
                    cameraPosition = .region(initialRegion)
                }
                await viewModel.fetchPlacesInRegion(initialRegion)
                viewModel.updateClusteredItems(for: initialRegion)
            } else {
                let defaultRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 42.0, longitude: 12.5),
                    span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
                )
                cameraPosition = .region(defaultRegion)
                await viewModel.fetchPlacesInRegion(defaultRegion)
                viewModel.updateClusteredItems(for: defaultRegion)
            }
        }
        .onChange(of: locationManager.location != nil) { _, hasLocation in
            if hasLocation, let newLocation = locationManager.location {
                let userRegion = MKCoordinateRegion(
                    center: newLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
                withAnimation {
                    cameraPosition = .region(userRegion)
                }
                // Carica i luoghi per la nuova regione dell'utente
                Task {
                    await viewModel.fetchPlacesInRegion(userRegion)
                    viewModel.updateClusteredItems(for: userRegion)
                }
            }
        }
        .onChange(of: viewModel.regionToRecenter) { _, newRegionWrapper in
            if let wrapper = newRegionWrapper {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    cameraPosition = .region(wrapper.region)
                }
            }
        }
    }
}

// Pin personalizzato moderno - SEMPLIFICATO per performance
struct PlacePin: View {
    let place: Place
    let isVisited: Bool
    
    var pinColor: Color {
        isVisited ? .appVisited : .blue
    }
    
    var body: some View {
        // Pin semplificato senza animazioni pesanti
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(Color.appAccent, pinColor)
            .shadow(color: pinColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// Cluster Pin
struct ClusterPin: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 36, height: 36)
                .shadow(color: Color.blue.opacity(0.4), radius: 4, x: 0, y: 2)
            
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appAccent)
        }
    }
}

