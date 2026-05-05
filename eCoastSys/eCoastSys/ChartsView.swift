//
//  ChartsView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI

struct ChartsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("Temperature & Tides")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ecSecondary)                                    .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 260)
                            .overlay(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Charts coming soon")
                                        .font(.title3)
                                        .foregroundStyle(Color.ecSecondaryText)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.ecPrimary.opacity(0.12))
                                        .frame(height: 110)
                                        .overlay {
                                            Text("Future chart area")
                                                .foregroundStyle(Color.ecPrimary)
                                                .font(.headline)
                                        }
                                }
                                .padding(20)
                            }
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ChartsView()
}
