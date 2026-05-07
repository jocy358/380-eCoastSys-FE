//
//  SpeciesView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI
 
struct SpeciesView: View {
    @State private var sightings: [SpeciesSightingDTO] = []
    @State private var previousSightings: [SpeciesSightingDTO] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedGroup = "All"
 
    let groups = ["All", "Marine mammals", "Birds", "Invertebrates", "Marine"]
 
    var filtered: [SpeciesSightingDTO] {
        sightings.filter { sighting in
            let matchesSearch = searchText.isEmpty ||
                commonName(for: sighting).localizedCaseInsensitiveContains(searchText) ||
                sighting.speciesName.localizedCaseInsensitiveContains(searchText) ||
                sighting.scientificName.localizedCaseInsensitiveContains(searchText)
            let matchesGroup = selectedGroup == "All" ||
                sighting.group.localizedCaseInsensitiveContains(selectedGroup)
            return matchesSearch && matchesGroup
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
                            // Header + search
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
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ecSecondary, lineWidth: 1.8))
                                .shadow(color: Color.ecSecondary.opacity(0.12), radius: 5, y: 2)
 
                                // Group filter pills
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(groups, id: \.self) { group in
                                            Button(action: { selectedGroup = group }) {
                                                Text(group)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule().fill(selectedGroup == group ? Color.ecSecondary : Color.white)
                                                    )
                                                    .foregroundStyle(selectedGroup == group ? Color.white : Color.ecSecondary)
                                                    .overlay(Capsule().stroke(Color.ecSecondary, lineWidth: 1.5))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
 
                            // Species rows
                            ForEach(filtered) { sighting in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(commonName(for: sighting))
                                                .font(.headline)
                                                .foregroundStyle(Color.ecText)
                                            Text(sighting.scientificName
                                                .components(separatedBy: "(").first?
                                                .components(separatedBy: " ")
                                                .filter { word in
                                                    !word.contains(",") &&
                                                    !(word.first?.isUppercase == true && word != sighting.scientificName.components(separatedBy: " ").first)
                                                }
                                                .prefix(2)
                                                .joined(separator: " ")
                                                .trimmingCharacters(in: .whitespaces) ?? sighting.scientificName)
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
                                            // Trend indicator
                                            trendView(for: sighting)
                                        }
                                    }
 
                                    Divider()
                                        .overlay(Color.ecSecondary.opacity(0.2))
 
                                    // Bottom row — location + last seen
                                    HStack {
                                        Label(locationLabel(for: sighting), systemImage: "mappin.circle")
                                            .font(.caption2)
                                            .foregroundStyle(Color.ecSecondaryText)
                                        Spacer()
                                        Label(lastSeenLabel(for: sighting), systemImage: "clock")
                                            .font(.caption2)
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
                .task { await loadData() }
                .refreshable { await loadData() }
            }
        }
    }
  
    @ViewBuilder
    func trendView(for sighting: SpeciesSightingDTO) -> some View {
        let trend = trendDelta(for: sighting)
        if trend != 0 {
            HStack(spacing: 2) {
                Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text("\(abs(trend)) this week")
                    .font(.caption2)
            }
            .foregroundStyle(trend > 0 ? Color.green : Color.red)
        }
    }
 
    func trendDelta(for sighting: SpeciesSightingDTO) -> Int {
        guard let previous = previousSightings.first(where: { $0.id == sighting.id }) else { return 0 }
        return sighting.count - previous.count
    }
 
    func locationLabel(for sighting: SpeciesSightingDTO) -> String {
        let lat = sighting.latitude
        let lon = sighting.longitude
        if lat > 36.7 && lat < 37.0 && lon > -122.1 && lon < -121.8 {
            return "Monterey Bay"
        } else if lat > 36.7 && lat < 36.9 && lon > -122.1 && lon < -121.9 {
            return "Moss Landing"
        } else if lat > 36.9 && lon > -122.1 {
            return "Santa Cruz"
        } else {
            return String(format: "%.2f, %.2f", lat, lon)
        }
    }
 
    func lastSeenLabel(for sighting: SpeciesSightingDTO) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: sighting.sightedAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: sighting.sightedAt) else {
                return "Unknown"
            }
            return relativeDate(date2)
        }
        return relativeDate(date)
    }
 
    func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        case 7...13: return "1 week ago"
        default: return "\(days / 7) weeks ago"
        }
    }
 
    func loadData() async {
        isLoading = true
        do {
            previousSightings = sightings
            sightings = try await CoastalAPIClient.shared.fetchSpecies()
        } catch {
            print("Error fetching species: \(error)")
        }
        isLoading = false
    }
    
    func commonName(for sighting: SpeciesSightingDTO) -> String {
        let names: [String: String] = [
            // Marine mammals
            "Enhydra lutris": "Sea Otter",
            "Grampus griseus": "Risso's Dolphin",
            // Birds
            "Anas platyrhynchos": "Mallard Duck",
            "Ardea alba": "Great Egret",
            "Buteo jamaicensis": "Red-tailed Hawk",
            "Egretta thula": "Snowy Egret",
            "Euphagus cyanocephalus": "Brewer's Blackbird",
            "Fulica americana": "American Coot",
            "Larus brachyrhynchus": "Short-billed Gull",
            "Larus occidentalis": "Western Gull",
            "Melospiza lincolnii": "Lincoln's Sparrow",
            "Numenius americanus": "Long-billed Curlew",
            "Pipilo maculatus": "Spotted Towhee",
            "Sialia mexicana": "Western Bluebird",
            "Sitta pygmaea": "Pygmy Nuthatch",
            "Turdus migratorius": "American Robin",
            "Zonotrichia atricapilla": "Golden-crowned Sparrow",
            "Zonotrichia leucophrys": "White-crowned Sparrow",
            "Aphelocoma californica": "California Scrub-Jay",
            // Invertebrates
            "Acanthodoris rhodoceras": "Horned Nudibranch",
            "Aldisa sanguinea": "Red Aldisa Nudibranch",
            "Anthopleura artemisia": "Moonglow Anemone",
            "Anthopleura sola": "Sunburst Anemone",
            "Cadlina luteomarginata": "Yellow-edged Cadlina",
            "Calliostoma ligatum": "Blue Top Snail",
            "Clinocottus analis": "Wooly Sculpin",
            "Diaulula sandiegensis": "Ring-spotted Dorid",
            "Dirona picta": "Painted Dirona",
            "Doriopsilla albopunctata": "White-spotted Doris",
            "Doriopsilla fulva": "Tawny Doris",
            "Doris montereyensis": "Monterey Doris",
            "Henricia pumila": "Blood Star",
            "Hermissenda opalescens": "Opalescent Nudibranch",
            "Lepidozona mertensii": "Merten's Chiton",
            "Lissothuria nutriens": "Sea Cucumber",
            "Pachygrapsus crassipes": "Striped Shore Crab",
            "Pagurus venturensis": "Hermit Crab",
            "Peltodoris nobilis": "Noble Sea Lemon",
            "Pentidotea aculeata": "Kelp Isopod",
            "Phidiana hiltoni": "Hilton's Aeolid",
            "Pisaster ochraceus": "Ochre Sea Star",
            "Pugettia richii": "Kelp Crab",
            "Strongylocentrotus purpuratus": "Purple Sea Urchin",
            "Tetraclita rubescens": "Pink Acorn Barnacle",
            "Triopha maculata": "Spotted Triopha",
            // Amphibians
            "Ambystoma californiense": "California Tiger Salamander",
            "Ambystoma macrodactylum": "Long-toed Salamander",
            "Aneides lugubris": "Arboreal Salamander",
            "Ensatina eschscholtzii": "Ensatina Salamander",
            // Plants and fungi (Marine catch-all)
            "Arctostaphylos andersonii": "Heartleaf Manzanita",
            "Arctostaphylos nummularia": "Fort Bragg Manzanita",
            "Armillaria mellea": "Honey Mushroom",
            "Baccharis pilularis": "Coyote Brush",
            "Diplacus aurantiacus": "Sticky Monkeyflower",
            "Ericameria arborescens": "Golden Fleece",
            "Heteromeles arbutifolia": "Toyon",
            "Laccaria amethysteo-occidentalis": "Western Amethyst Laccaria",
            "Lactarius rubidus": "Candy Cap Mushroom",
            "Patiria miniata": "Bat Star",
            "Pelvetiopsis limitata": "Rockweed",
            "Rhopalomyia californica": "Coyote Brush Gall Midge",
            "Vaccinium ovatum": "California Huckleberry",
            "Odocoileus hemionus": "Mule Deer",
            "Gibbonsia montereyensis": "Crevice Kelpfish",
        ]
        for (scientific, common) in names {
            if sighting.scientificName.lowercased().hasPrefix(scientific.lowercased()) {
                return common
            }
        }
        let parts = sighting.speciesName
            .components(separatedBy: " ")
            .filter { !$0.contains(",") && !$0.first!.isUppercase || $0 == sighting.speciesName.components(separatedBy: " ").first }
        if parts.count >= 2 {
            return parts.prefix(2).joined(separator: " ")
        }
        return sighting.speciesName
    }

}
 
#Preview {
    SpeciesView()
}
