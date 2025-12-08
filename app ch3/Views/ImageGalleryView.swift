//
//  ImageGalleryView.swift
//  app ch3
//
//  Full-screen image gallery with zoom and swipe
//

import SwiftUI

struct ImageGalleryView: View {
    let images: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGFloat = 0
    
    init(images: [String], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.images = images
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Image pager
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                    ZoomableImageView(
                        imageUrl: imageUrl,
                        scale: $scale,
                        offset: $offset
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if scale == 1.0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if abs(dragOffset) > 100 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            
            // Overlay controls
            VStack {
                // Top bar
                HStack {
                    Button {
                        withAnimation {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if images.count > 1 {
                        Text("\(currentIndex + 1) / \(images.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .padding(.top, 40)
                
                Spacer()
                
                // Page indicators
                if images.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentIndex)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.bottom, 40)
                }
            }
        }
        .statusBarHidden()
    }
}

struct ZoomableImageView: View {
    let imageUrl: String
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.2 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: value.translation.width,
                                            height: value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if scale <= 1 {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// Helper extension to parse images from Place
extension Place {
    var imageUrls: [String] {
        var urls: [String] = []
        
        // Add cover image first
        if let cover = image_cover {
            urls.append(cover)
        }
        
        // Parse images JSON field if it exists
        if let imagesString = images {
            // Try parsing as JSON array
            if let data = imagesString.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String].self, from: data) {
                urls.append(contentsOf: parsed.filter { !urls.contains($0) })
            } else {
                // Try comma-separated
                let separated = imagesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                urls.append(contentsOf: separated.filter { !urls.contains($0) && !$0.isEmpty })
            }
        }
        
        // Add thumbnail as fallback
        if urls.isEmpty, let thumbnail = thumbnail_url {
            urls.append(thumbnail)
        }
        
        return urls
    }
}

#Preview {
    ImageGalleryView(
        images: [
            "https://picsum.photos/800/600",
            "https://picsum.photos/800/601",
            "https://picsum.photos/800/602"
        ],
        isPresented: .constant(true)
    )
}
