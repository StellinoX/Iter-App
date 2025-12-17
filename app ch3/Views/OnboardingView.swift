//
//  OnboardingView.swift
//  app ch3
//
//  Onboarding tutorial shown on first app launch
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "map.fill",
            iconColor: .green,
            title: "Discover Hidden Gems",
            subtitle: "Find secret places that tourists don't know about. Explore underground crypts, hidden gardens, and forgotten monuments.",
            gradient: [Color.green.opacity(0.3), Color.clear]
        ),
        OnboardingPage(
            icon: "sparkles",
            iconColor: .purple,
            title: "AI Trip Planner",
            subtitle: "Let our AI create the perfect itinerary for you. Select places, get restaurant suggestions, and optimize your route.",
            gradient: [Color.purple.opacity(0.3), Color.clear]
        ),
        OnboardingPage(
            icon: "heart.fill",
            iconColor: .pink,
            title: "Save Your Favorites",
            subtitle: "Mark places as visited, save your favorites, and track your exploration progress across cities.",
            gradient: [Color.pink.opacity(0.3), Color.clear]
        )
    ]
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.appAccent : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 30)
                
                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack {
                        Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            .fontWeight(.semibold)
                        if currentPage < pages.count - 1 {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: page.gradient,
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                
                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundColor(page.iconColor)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.spring(response: 0.5)) {
            isCompleted = true
        }
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let gradient: [Color]
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
