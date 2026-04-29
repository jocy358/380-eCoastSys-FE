//
//  MapView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI

struct MapView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("Coastal Map")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ecSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    
                    VStack(spacing: 20) {
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.75))
                            .overlay {
                                Text("Map coming soon")
                                    .font(.title3)
                                    .foregroundStyle(Color.ecText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 420)
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}


#Preview {
    MapView()
}
