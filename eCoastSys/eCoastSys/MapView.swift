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
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
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
    @State private var anomalousStations: Set<String> = []
    @State private var speciesSightings: [SpeciesSightingDTO] = []
    @State private var selectedStation: CoastalStation? = nil
    @State private var selectedSighting: SpeciesSightingDTO? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.ecBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    Text("Coastal Map")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ecSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 6)

                    // Map
                    ZStack(alignment: .bottomTrailing) {
                        Map(position: $position, interactionModes: [.zoom, .pan, .rotate]) {
                            ForEach(stations) { station in
                                Annotation(station.name, coordinate: station.coordinate) {
                                    Button { selectedStation = station } label: {
                                        ZStack(alignment: .topTrailing) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.ecPrimary)
                                                    .frame(width: 22, height: 22)
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                                    .frame(width: 22, height: 22)
                                                Image(systemName: "antenna.radiowaves.left.and.right")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            if anomalousStations.contains(station.id) {
                                                Circle()
                                                    .fill(Color.ecTan)
                                                    .frame(width: 9, height: 9)
                                                    .offset(x: 3, y: -3)
                                            }
                                        }
                                    }
                                    .accessibilityLabel("\(station.name) NOAA station\(anomalousStations.contains(station.id) ? ", anomaly detected" : "")")
                                }
                            }

                            ForEach(speciesSightings) { sighting in
                                Annotation(sighting.speciesName, coordinate: CLLocationCoordinate2D(latitude: sighting.latitude, longitude: sighting.longitude)) {
                                    Button { selectedSighting = sighting } label: {
                                        ZStack {
                                            Circle().fill(Color.ecSecondary.opacity(0.85)).frame(width: 13, height: 13)
                                            Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 13, height: 13)
                                        }
                                    }
                                    .accessibilityLabel(sighting.speciesName)
                                }
                            }
                        }
                        .mapStyle(.standard)
                        .frame(height: 650)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

                        MapLegend()
                            .padding([.trailing, .bottom], 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
                if hasAnomaly { anomalousStations.insert(id) }
            }
        }
    }
}

// MARK: - Map Legend

private struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LegendRow(color: Color.ecPrimary, label: "NOAA Station")
            LegendRow(color: Color.ecSecondary, label: "Species Sighting")
            HStack(spacing: 6) {
                Circle().fill(Color.ecTan).frame(width: 8, height: 8)
                Text("Anomaly Active").font(.caption2).foregroundStyle(Color.ecSecondaryText)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

private struct LegendRow: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(Color.ecSecondaryText)
        }
    }
}

// MARK: - Station Detail Sheet

struct StationDetailSheet: View {
    let station: CoastalStation

    @State private var readings: [WaterReadingDTO] = []
    @State private var anomalies: [WaterReadingDTO] = []
    @State private var marineReadings: [MarineReadingDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var latest: WaterReadingDTO? { readings.last }
    private var currentMarine: MarineReadingDTO? { marineReadings.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView("Loading data…")
                            .tint(Color.ecPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        ContentUnavailableView(
                            "Unable to Load",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text(error)
                        )
                    } else if !station.hasTemperatureData {
                        if marineReadings.isEmpty {
                            ContentUnavailableView(
                                "No Marine Data",
                                systemImage: "water.waves.slash",
                                description: Text("Could not fetch Open-Meteo marine data for \(station.name).")
                            )
                        } else {
                            ScrollView {
                                VStack(spacing: 16) {
                                    // Marine stats card
                                    if let m = currentMarine {
                                        MarineStatsCard(reading: m)
                                    }

                                    // Source banner
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(Color.ecSecondary)
                                        Text("Marine forecast from Open-Meteo. NOAA water temperature is unavailable at this station.")
                                            .font(.caption)
                                            .foregroundStyle(Color.ecSecondaryText)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.ecSecondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                                    // Hourly forecast
                                    SectionCard(title: "24 h Marine Forecast (\(marineReadings.count) readings)") {
                                        ForEach(marineReadings) { r in
                                            HStack(alignment: .top) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(r.time)
                                                        .font(.caption).foregroundStyle(Color.ecSecondaryText)
                                                    if let sst = r.seaSurfaceTemperature {
                                                        Text(String(format: "🌡 %.1f °C", sst))
                                                            .font(.caption.monospacedDigit())
                                                            .foregroundStyle(Color.ecText)
                                                    }
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    if let wh = r.waveHeight {
                                                        Text(String(format: "🌊 %.2f m", wh))
                                                            .font(.caption.monospacedDigit().bold())
                                                            .foregroundStyle(Color.ecPrimary)
                                                    }
                                                    if let wp = r.wavePeriod {
                                                        Text(String(format: "⏱ %.1f s", wp))
                                                            .font(.caption.monospacedDigit())
                                                            .foregroundStyle(Color.ecSecondaryText)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            if r.id != marineReadings.last?.id { Divider() }
                                        }
                                    }
                                }
                                .padding(20)
                            }
                        }
                    } else if readings.isEmpty {
                        ContentUnavailableView(
                            "No Readings Yet",
                            systemImage: "clock.badge.xmark",
                            description: Text("No data has been ingested for this station yet.")
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                if let r = latest {
                                    StatsCardView(reading: r)
                                }

                                if !anomalies.isEmpty {
                                    SectionCard(title: "⚠️ Active Anomalies (\(anomalies.count))") {
                                        ForEach(anomalies) { a in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(a.recordedAt)
                                                        .font(.caption).foregroundStyle(Color.ecSecondaryText)
                                                    Text(String(format: "%.1f °C", a.temperature))
                                                        .font(.body.monospacedDigit())
                                                        .foregroundStyle(Color.ecTan)
                                                }
                                                Spacer()
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(Color.ecTan)
                                            }
                                            .padding(.vertical, 4)
                                            if a.id != anomalies.last?.id { Divider() }
                                        }
                                    }
                                }

                                SectionCard(title: "Last 24 h  (\(readings.count) readings)") {
                                    ForEach(readings.reversed()) { reading in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(reading.recordedAt)
                                                    .font(.caption).foregroundStyle(Color.ecSecondaryText)
                                                Text(String(format: "%.1f °C  •  tide %.2f m  •  QI %d",
                                                            reading.temperature,
                                                            reading.tideHeight,
                                                            reading.qualityIndex))
                                                    .font(.caption.monospacedDigit())
                                                    .foregroundStyle(Color.ecText)
                                            }
                                            Spacer()
                                            if reading.isAnomaly {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(Color.ecTan)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        if reading.id != readings.first?.id { Divider() }
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
            .navigationTitle(station.name)
            .navigationSubtitle(station.hasTemperatureData ? "NOAA Station \(station.id)" : "Open-Meteo Marine")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await fetchData() }
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        if station.hasTemperatureData {
            do {
                async let r = CoastalAPIClient.shared.fetchReadings(forStation: station.id, days: 1)
                async let a = CoastalAPIClient.shared.fetchAnomalies(forStation: station.id)
                readings  = try await r
                anomalies = try await a
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            marineReadings = (try? await CoastalAPIClient.shared.fetchMarineReadings(
                latitude: station.coordinate.latitude,
                longitude: station.coordinate.longitude
            )) ?? []
        }
        isLoading = false
    }
}

// MARK: - Marine Stats Card

private struct MarineStatsCard: View {
    let reading: MarineReadingDTO

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .frame(height: 100)
            .overlay {
                HStack(spacing: 0) {
                    StatCell(
                        value: reading.waveHeight.map { String(format: "%.2f m", $0) } ?? "—",
                        label: "Wave Height",
                        icon: "water.waves",
                        color: Color.ecSecondary
                    )
                    Divider().padding(.vertical, 16)
                    StatCell(
                        value: reading.wavePeriod.map { String(format: "%.1f s", $0) } ?? "—",
                        label: "Wave Period",
                        icon: "timer",
                        color: Color.ecPrimary
                    )
                    Divider().padding(.vertical, 16)
                    StatCell(
                        value: reading.seaSurfaceTemperature.map { String(format: "%.1f°C", $0) } ?? "—",
                        label: "Sea Temp",
                        icon: "thermometer.medium",
                        color: Color.ecMuted
                    )
                }
            }
    }
}

// MARK: - Stats Card

private struct StatsCardView: View {
    let reading: WaterReadingDTO

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .frame(height: 100)
            .overlay {
                HStack(spacing: 0) {
                    StatCell(value: String(format: "%.1f°C", reading.temperature),
                             label: "Temperature",
                             icon: "thermometer.medium",
                             color: reading.isAnomaly ? Color.ecTan : Color.ecPrimary)
                    Divider().padding(.vertical, 16)
                    StatCell(value: String(format: "%.2f m", reading.tideHeight),
                             label: "Tide Height",
                             icon: "water.waves",
                             color: Color.ecSecondary)
                    Divider().padding(.vertical, 16)
                    StatCell(value: "\(reading.qualityIndex)",
                             label: "Quality Index",
                             icon: "checkmark.seal",
                             color: reading.qualityIndex >= 80 ? Color.ecPrimary : Color.ecTan)
                }
            }
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
                .foregroundStyle(Color.ecText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ecSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Card

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Color.ecSecondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }
}

// MARK: - Species Sighting Sheet

struct SpeciesSightingSheet: View {
    let sighting: SpeciesSightingDTO

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        SectionCard(title: "Identification") {
                            InfoRow(label: "Common Name", value: sighting.speciesName)
                            Divider()
                            HStack {
                                Text("Scientific Name")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ecSecondaryText)
                                Spacer()
                                Text(sighting.scientificName)
                                    .font(.subheadline).italic()
                                    .foregroundStyle(Color.ecText)
                            }
                            Divider()
                            InfoRow(label: "Group", value: sighting.group.capitalized)
                        }

                        SectionCard(title: "Observation") {
                            InfoRow(label: "Count", value: "\(sighting.count)")
                            Divider()
                            InfoRow(label: "Sighted", value: sighting.sightedAt)
                            Divider()
                            InfoRow(label: "Latitude",  value: String(format: "%.4f°", sighting.latitude))
                            Divider()
                            InfoRow(label: "Longitude", value: String(format: "%.4f°", sighting.longitude))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(sighting.speciesName)
            .navigationSubtitle("GBIF Sighting")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.ecSecondaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.ecText)
        }
    }
}

#Preview {
    MapView()
}
