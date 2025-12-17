//
//  PlaceDetailView.swift
//  app ch3
//
//  Full details view for a secret place - Redesigned with Wikipedia info
//

import SwiftUI
import CoreLocation
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let userLocation: CLLocationCoordinate2D?
    @ObservedObject var viewModel: PlacesViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isFavorite: Bool = false
    @State private var isVisited: Bool = false
    @State private var showingGallery = false
    @State private var showingShareSheet = false
    @State private var noteText: String = ""
    @State private var isEditingNote = false
    
    // Wikipedia enrichment
    @State private var wikipediaInfo: WikipediaInfo?
    @State private var extraPhotos: [String] = []
    @State private var isLoadingEnrichment = false
    
    private let wikipediaService = WikipediaService()
    
    private var existingNoteText: String {
        UserDefaultsManager.shared.getNote(for: place.id)?.text ?? ""
    }
    
    private var distanceString: String? {
        guard let userLocation = userLocation,
              let placeCoordinate = place.coordinate else {
            return nil
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let placeCLLocation = CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: placeCLLocation)
        let distanceInKm = distanceInMeters / 1000.0
        
        if distanceInKm < 1 {
            return String(format: "%.0f m", distanceInMeters)
        } else {
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0f0720").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Image with Parallax effect
                    GeometryReader { geometry in
                        let minY = geometry.frame(in: .global).minY
                        
                        if let imageUrl = place.image_cover ?? place.thumbnail_url,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height + (minY > 0 ? minY : 0))
                                        .clipped()
                                        .offset(y: minY > 0 ? -minY : 0)
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(1.5)
                                        }
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .onTapGesture {
                                showingGallery = true
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if place.imageUrls.count > 1 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("\(place.imageUrls.count)")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .padding(12)
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                        }
                    }
                    .frame(height: 300)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Title Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text(place.displayName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button {
                                    isFavorite.toggle()
                                    viewModel.toggleFavorite(place.id)
                                } label: {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(isFavorite ? .red : .gray)
                                        .padding(10)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            
                            if let subtitle = place.subtitle {
                                Text(subtitle)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 16) {
                                if let location = place.fullLocation {
                                    Label(location, systemImage: "mappin.and.ellipse")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                if let dist = distanceString {
                                    Label(dist, systemImage: "figure.walk")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                if let coordinate = place.coordinate {
                                    openInMaps(coordinate: coordinate)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    Text("Directions")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Button {
                                isVisited.toggle()
                                viewModel.toggleVisited(place.id)
                            } label: {
                                HStack {
                                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                                    Text(isVisited ? "Visited" : "Mark Visited")
                                }
                                .font(.headline)
                                .foregroundColor(isVisited ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isVisited ? Color.green : Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Description
                        if let description = place.cleanDescription {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.9))
                                    .lineSpacing(4)
                            }
                        }
                        
                        // Wikipedia Extra Info
                        if let wikiInfo = wikipediaInfo, !wikiInfo.fullExtract.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "w.circle.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("From Wikipedia")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Text(wikiInfo.fullExtract)
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.9))
                                    .lineSpacing(4)
                                
                                // Wikipedia link
                                Link(destination: URL(string: wikiInfo.pageURL)!) {
                                    HStack {
                                        Text("Read more on Wikipedia")
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.appAccent)
                                }
                            }
                            .padding(.top, 8)
                        } else if isLoadingEnrichment {
                            HStack {
                                ProgressView()
                                    .tint(.gray)
                                    .scaleEffect(0.8)
                                Text("Loading extra info...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Extra Photos Gallery
                        if !extraPhotos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("More Photos")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(extraPhotos, id: \.self) { photoURL in
                                            if let url = URL(string: photoURL) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 200, height: 150)
                                                            .cornerRadius(12)
                                                            .clipped()
                                                    case .failure:
                                                        Color.gray.opacity(0.3)
                                                            .frame(width: 200, height: 150)
                                                            .cornerRadius(12)
                                                    default:
                                                        ProgressView()
                                                            .frame(width: 200, height: 150)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Directions Text
                        if let directions = place.cleanDirections {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Getting There")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(directions)
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.9))
                                    .lineSpacing(4)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Personal Notes Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.appAccent)
                                Text("My Notes")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                if noteText.isEmpty {
                                    Button {
                                        isEditingNote = true
                                    } label: {
                                        Text("Add Note")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.appAccent)
                                    }
                                }
                            }
                            
                            if isEditingNote {
                                VStack(spacing: 12) {
                                    TextEditor(text: $noteText)
                                        .frame(minHeight: 100)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        Button {
                                            isEditingNote = false
                                            noteText = existingNoteText
                                        } label: {
                                            Text("Cancel")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.7))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                        
                                        Spacer()
                                        
                                        if !noteText.isEmpty {
                                            Button {
                                                deleteNote()
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                                    .padding(8)
                                                    .background(Color.red.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        Button {
                                            saveNote()
                                        } label: {
                                            Text("Save")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.appAccent)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            } else if !noteText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(noteText)
                                        .font(.body)
                                        .foregroundColor(.gray.opacity(0.9))
                                        .lineSpacing(4)
                                    
                                    Button {
                                        isEditingNote = true
                                    } label: {
                                        Text("Edit")
                                            .font(.caption)
                                            .foregroundColor(.appAccent)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            } else {
                                Text("Add personal notes about this place...")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                                    .italic()
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        isEditingNote = true
                                    }
                            }
                        }
                        .padding(.top, 16)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                    .background(Color(hex: "0f0720"))
                    // Corner radius for the content sheet effect
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                    .offset(y: -20) // Overlap with image
                }
            }
        } // Close ZStack
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Share button
                Button {
                    sharePlace()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
        .fullScreenCover(isPresented: $showingGallery) {
            ImageGalleryView(images: place.imageUrls, isPresented: $showingGallery)
        }
        .onAppear {
            isFavorite = viewModel.isFavorite(place.id)
            isVisited = viewModel.isVisited(place.id)
            noteText = existingNoteText
        }
        .task {
            // Fetch Wikipedia info only (free, no API limits)
            isLoadingEnrichment = true
            
            // Get Wikipedia info
            if let info = await wikipediaService.getPlaceInfo(
                placeName: place.displayName,
                city: place.city
            ) {
                wikipediaInfo = info
                
                // Add Wikipedia image to extra photos
                if let imageURL = info.imageURL {
                    extraPhotos.append(imageURL)
                }
            }
            
            isLoadingEnrichment = false
        }
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = place.displayName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
    
    private func saveNote() {
        let note = PlaceNote(placeId: place.id, text: noteText)
        UserDefaultsManager.shared.saveNote(note)
        isEditingNote = false
    }
    
    private func deleteNote() {
        UserDefaultsManager.shared.deleteNote(for: place.id)
        noteText = ""
        isEditingNote = false
    }
    
    private func sharePlace() {
        var shareItems: [Any] = []
        
        // Text content
        var shareText = "🗺️ \(place.displayName)"
        if let location = place.fullLocation {
            shareText += "\n📍 \(location)"
        }
        if let description = place.cleanDescription?.prefix(150) {
            shareText += "\n\n\(description)..."
        }
        shareItems.append(shareText)
        
        // URL if available
        if let urlString = place.url, let url = URL(string: urlString) {
            shareItems.append(url)
        }
        
        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// Extension for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Conditional modifier extension
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

