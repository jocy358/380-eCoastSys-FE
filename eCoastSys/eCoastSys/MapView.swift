//
//  MapView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI
import MapKit

// MARK: - Station model

struct CoastalStation: Identifiable, Hashable {
    let id: String          // NOAA station ID
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// Whether NOAA offers water_temperature readings at this station.
    /// Moss Landing (9413616) and Santa Cruz (9413745) do NOT have this product.
    let hasTemperatureData: Bool

    static func == (lhs: CoastalStation, rhs: CoastalStation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private let knownStations: [CoastalStation] = [
    CoastalStation(id: "9413450", name: "Monterey",     coordinate: .init(latitude: 36.6050, longitude: -121.8886), hasTemperatureData: true),
    CoastalStation(id: "9413616", name: "Moss Landing", coordinate: .init(latitude: 36.8027, longitude: -121.7874), hasTemperatureData: false),
    CoastalStation(id: "9413745", name: "Santa Cruz",   coordinate: .init(latitude: 36.9618, longitude: -122.0183), hasTemperatureData: false),
]

// MARK: - MapView

struct MapView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.6800, longitude: -121.9200),
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )
    )
    @State private var stations: [CoastalStation] = knownStations
    @State private var anomalousSations: Set<String> = []       // stationIds with active anomalies
    @State private var speciesSightings: [SpeciesSightingDTO] = []

    @State private var selectedStation: CoastalStation? = nil
    @State private var selectedSighting: SpeciesSightingDTO? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position, interactionModes: .all) {
                    // ── NOAA Station pins ──────────────────────────────
                    ForEach(stations) { station in
                        Annotation(station.name, coordinate: station.coordinate) {
                            Button { selectedStation = station } label: {
                                ZStack(alignment: .topTrailing) {
                                    ZStack {
                                        Circle().fill(.blue).frame(width: 18, height: 18)
                                        Circle().stroke(.white, lineWidth: 2).frame(width: 18, height: 18)
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    if anomalousSations.contains(station.id) {
                                        Circle()
                                            .fill(.orange)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 3, y: -3)
                                    }
                                }
                            }
                            .accessibilityLabel("\(station.name) NOAA station\(anomalousSations.contains(station.id) ? ", anomaly detected" : "")")
                        }
                    }

                    // ── Species sighting pins ─────────────────────────
                    ForEach(speciesSightings) { sighting in
                        Annotation(sighting.speciesName, coordinate: CLLocationCoordinate2D(latitude: sighting.latitude, longitude: sighting.longitude)) {
                            Button { selectedSighting = sighting } label: {
                                ZStack {
                                    Circle().fill(.teal.opacity(0.85)).frame(width: 12, height: 12)
                                    Circle().stroke(.white, lineWidth: 1.5).frame(width: 12, height: 12)
                                }
                            }
                            .accessibilityLabel(sighting.speciesName)
                        }
                    }
                }
                .mapStyle(.standard)
                .ignoresSafeArea(edges: .bottom)

                // ── Legend ────────────────────────────────────────────
                MapLegend()
                    .padding([.trailing, .bottom], 16)
                    .padding(.bottom, 60)
            }
            .navigationTitle("Coastal Map")
            .sheet(item: $selectedStation) { station in
                StationDetailSheet(station: station)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedSighting) { sighting in
                SpeciesSightingSheet(sighting: sighting)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .task { await loadAll() }
        }
    }

    private func loadAll() async {
        async let sightingsTask = CoastalAPIClient.shared.fetchSpecies()
        await loadAnomalyStations()
        speciesSightings = (try? await sightingsTask) ?? []
    }

    private func loadAnomalyStations() async {
        await withTaskGroup(of: (String, Bool).self) { group in
            for station in knownStations where station.hasTemperatureData {
                group.addTask {
                    let anomalies = try? await CoastalAPIClient.shared.fetchAnomalies(forStation: station.id)
                    return (station.id, !(anomalies ?? []).isEmpty)
                }
            }
            for await (id, hasAnomaly) in group {
                if hasAnomaly { anomalousSations.insert(id) }
            }
        }
    }
}

// MARK: - Map Legend

private struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: .blue, label: "NOAA Station")
            LegendRow(color: .teal, label: "Species Sighting")
            HStack(spacing: 6) {
                Circle().fill(.orange).frame(width: 8, height: 8)
                Text("Anomaly Active").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct LegendRow: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Station Detail Sheet

struct StationDetailSheet: View {
    let station: CoastalStation

    @State private var readings: [WaterReadingDTO] = []
    @State private var anomalies: [WaterReadingDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var latest: WaterReadingDTO? { readings.last }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading NOAA data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text(error)
                    )
                } else if !station.hasTemperatureData {
                    ContentUnavailableView(
                        "No Temperature Data",
                        systemImage: "thermometer.slash",
                        description: Text("NOAA does not offer water temperature readings at \(station.name) (\(station.id)).")
                    )
                } else if readings.isEmpty {
                    ContentUnavailableView(
                        "No Readings Yet",
                        systemImage: "clock.badge.xmark",
                        description: Text("No data has been ingested for this station yet. Try triggering a refresh from the backend.")
                    )
                } else {
                    List {
                        // ── Stats card ───────────────────────────────
                        if let r = latest {
                            Section {
                                StatsCardView(reading: r)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                        }

                        // ── Active anomalies ──────────────────────────
                        if !anomalies.isEmpty {
                            Section("⚠️ Active Anomalies (\(anomalies.count))") {
                                ForEach(anomalies) { a in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(a.recordedAt)
                                                .font(.caption).foregroundStyle(.secondary)
                                            Text(String(format: "%.1f °C", a.temperature))
                                                .font(.body.monospacedDigit())
                                                .foregroundStyle(.orange)
                                        }
                                        Spacer()
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }

                        // ── 24h history ───────────────────────────────
                        Section("Last 24 h  (\(readings.count) readings)") {
                            ForEach(readings.reversed()) { reading in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reading.recordedAt)
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(String(format: "%.1f °C  •  tide %.2f m  •  QI %d",
                                                    reading.temperature,
                                                    reading.tideHeight,
                                                    reading.qualityIndex))
                                            .font(.caption.monospacedDigit())
                                    }
                                    Spacer()
                                    if reading.isAnomaly {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(station.name)
            .navigationSubtitle("NOAA Station \(station.id)")
        }
        .task { await fetchData() }
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let r = CoastalAPIClient.shared.fetchReadings(forStation: station.id, days: 1)
            async let a = CoastalAPIClient.shared.fetchAnomalies(forStation: station.id)
            readings  = try await r
            anomalies = try await a
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stats Card

private struct StatsCardView: View {
    let reading: WaterReadingDTO

    var body: some View {
        HStack(spacing: 0) {
            StatCell(value: String(format: "%.1f°C", reading.temperature),
                     label: "Temperature",
                     icon: "thermometer.medium",
                     color: reading.isAnomaly ? .orange : .blue)
            Divider()
            StatCell(value: String(format: "%.2f m", reading.tideHeight),
                     label: "Tide Height",
                     icon: "water.waves",
                     color: .teal)
            Divider()
            StatCell(value: "\(reading.qualityIndex)",
                     label: "Quality Index",
                     icon: "checkmark.seal",
                     color: reading.qualityIndex >= 80 ? .green : .yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}

private struct StatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Species Sighting Sheet

struct SpeciesSightingSheet: View {
    let sighting: SpeciesSightingDTO

    var body: some View {
        NavigationStack {
            List {
                Section("Identification") {
                    LabeledContent("Common Name", value: sighting.speciesName)
                    LabeledContent("Scientific Name") {
                        Text(sighting.scientificName).italic()
                    }
                    LabeledContent("Group", value: sighting.group.capitalized)
                }
                Section("Observation") {
                    LabeledContent("Count", value: "\(sighting.count)")
                    LabeledContent("Sighted", value: sighting.sightedAt)
                    LabeledContent("Latitude",  value: String(format: "%.4f°", sighting.latitude))
                    LabeledContent("Longitude", value: String(format: "%.4f°", sighting.longitude))
                }
            }
            .navigationTitle(sighting.speciesName)
            .navigationSubtitle("GBIF Sighting")
        }
    }
}

#Preview {
    MapView()
}
