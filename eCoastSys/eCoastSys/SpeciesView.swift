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
            Group {
                if isLoading {
                    ProgressView("Loading species...")
                } else if sightings.isEmpty {
                    ContentUnavailableView(
                        "No sightings found",
                        systemImage: "fish",
                        description: Text("Pull to refresh or check your connection")
                    )
                } else {
                    List(filtered) { sighting in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sighting.speciesName)
                                    .font(.headline)
                                Text(sighting.scientificName)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(sighting.count)")
                                    .font(.title3)
                                    .bold()
                                    .foregroundStyle(.teal)
                                Text("sightings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .searchable(text: $searchText, prompt: "Search species")
                }
            }
            .navigationTitle("Species Sightings")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
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
