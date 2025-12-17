//
//  AnimatedBackground.swift
//  app ch3
//
//  Shared animated purple gradient background with floating lights
//

import SwiftUI
import Combine

// MARK: - Animated Background with Moving Lights

struct AnimatedBackground: View {
    @State private var light1 = CGPoint(x: 0.3, y: 0.2)
    @State private var light2 = CGPoint(x: 0.7, y: 0.6)
    @State private var light3 = CGPoint(x: 0.5, y: 0.8)
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Base dark purple
            Color(hex: "0f0720")
            
            // Light orb 1 - Pink/Purple
            lightOrb(position: light1, color: Color(hex: "f472b6"), size: 0.5)
            
            // Light orb 2 - Purple
            lightOrb(position: light2, color: Color(hex: "a855f7"), size: 0.4)
            
            // Light orb 3 - Blue-Purple
            lightOrb(position: light3, color: Color(hex: "818cf8"), size: 0.35)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            moveLights()
        }
        .onAppear {
            moveLights()
        }
    }
    
    private func lightOrb(position: CGPoint, color: Color, size: CGFloat) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.5),
                            color.opacity(0.2),
                            color.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * size
                    )
                )
                .frame(width: geo.size.width * size * 2, height: geo.size.width * size * 2)
                .position(
                    x: geo.size.width * position.x,
                    y: geo.size.height * position.y
                )
                .blur(radius: 30)
        }
    }
    
    private func moveLights() {
        withAnimation(.easeInOut(duration: 2.5)) {
            light1 = CGPoint(x: .random(in: 0.1...0.5), y: .random(in: 0.1...0.4))
        }
        withAnimation(.easeInOut(duration: 3.0)) {
            light2 = CGPoint(x: .random(in: 0.5...0.9), y: .random(in: 0.3...0.7))
        }
        withAnimation(.easeInOut(duration: 3.5)) {
            light3 = CGPoint(x: .random(in: 0.2...0.8), y: .random(in: 0.6...0.9))
        }
    }
}

// MARK: - View Extension for Easy Application

extension View {
    /// Applies the animated purple gradient background
    func animatedBackground() -> some View {
        ZStack {
            AnimatedBackground()
            self
        }
    }
}

#Preview {
    Text("Hello World")
        .foregroundColor(.white)
        .animatedBackground()
}
