import SwiftUI

// MARK: - Reusable Bottom Sheet Component
// Save this for future use! It features:
// - 20px rounded top corners
// - White background extending to bottom safe area
// - Smooth slide up/down animation (125ms)
// - Scrim overlay that dismisses on tap
//
// Note: This component uses the RoundedCorner struct defined in HomeScreen.swift

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    @State private var isAnimating = false
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Scrim
                Color.black.opacity(isAnimating ? 0.4 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissWithAnimation()
                    }
                
                // Bottom sheet
                VStack(spacing: 0) {
                    content
                    
                    // Bottom padding to account for safe area
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.bottom + 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
                .offset(y: isAnimating ? geometry.safeAreaInsets.bottom : 400)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeOut(duration: 0.125), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
        .onChange(of: isPresented) { oldValue, newValue in
            if !newValue {
                dismissWithAnimation()
            }
        }
    }
    
    private func dismissWithAnimation() {
        isAnimating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.125) {
            isPresented = false
        }
    }
}

// MARK: - Example Usage
/*
 
struct ExampleView: View {
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            Button("Show Sheet") {
                showSheet = true
            }
            
            if showSheet {
                BottomSheet(isPresented: $showSheet) {
                    // Header
                    HStack {
                        Text("Sheet Title")
                            .font(.headline)
                        Spacer()
                        Button(action: { showSheet = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // Your content here
                    Text("Sheet content goes here")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
    }
}
 
*/
