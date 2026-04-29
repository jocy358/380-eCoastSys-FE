//
//  SpeciesView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI

struct SpeciesView: View {
    @State private var sightings: [SpeciesSightingDTO] = []
    @State private var isLoading = false
    @State private var searchText = ""

    var filtered: [SpeciesSightingDTO] {
        if searchText.isEmpty { return sightings }
        return sightings.filter {
            $0.speciesName.localizedCaseInsensitiveContains(searchText) ||
            $0.scientificName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView("Loading species...")
                            .tint(.ecPrimary)
                            .foregroundStyle(Color.ecText)
                    } else if sightings.isEmpty {
                        ContentUnavailableView(
                            "No sightings found",
                            systemImage: "fish",
                            description: Text("Pull to refresh or check your connection")
                        )
                    } else {
                        List {
                            VStack(spacing: 12) {
                                Text("Species Sightings")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(Color.ecSecondary)
                                    .frame(maxWidth: .infinity)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(Color.ecSecondary)
                                    
                                    TextField("Search species", text: $searchText)
                                        .foregroundStyle(Color.ecText)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.ecSecondary, lineWidth: 1.8)
                                )
                                .shadow(color: Color.ecSecondary.opacity(0.12), radius: 5, y: 2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            
                            ForEach(filtered) { sighting in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sighting.speciesName)
                                            .font(.headline)
                                            .foregroundStyle(Color.ecText)
                                        Text(sighting.scientificName)
                                            .font(.caption)
                                            .italic()
                                            .foregroundStyle(Color.ecSecondaryText)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(sighting.count)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(Color.ecPrimary)
                                        Text("sightings")
                                            .font(.caption)
                                            .foregroundStyle(Color.ecSecondaryText)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.ecSecondary, lineWidth: 1.8)
                                        )
                                )
                                .shadow(color: Color.ecSecondary.opacity(0.25), radius: 8, y: 3)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding(.top, 8)
                .task {
                    await loadData()
                }
                .refreshable {
                    await loadData()
                }
            }
        }
    }

    func loadData() async {
        isLoading = true
        do {
            sightings = try await CoastalAPIClient.shared.fetchSpecies()
        } catch {
            print("Error fetching species: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    SpeciesView()
}
