//
//  ChartsView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.

import SwiftUI
import Combine
import Charts

// MARK: - Data Models

struct TemperatureReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isAnomaly: Bool
}

struct TideReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WaveReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WaterQualityReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - ViewModel Protocol

@MainActor
protocol ChartsViewModelProtocol: ObservableObject {
    var temperatureReadings: [TemperatureReading] { get }
    var tideReadings: [TideReading] { get }
    var waveReadings: [WaveReading] { get }
    var waterQualityReadings: [WaterQualityReading] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var selectedStation: String { get set }
    func fetchData(range: TimeRange) async
}

enum TimeRange: String, CaseIterable {
    case week    = "7D"
    case month   = "30D"
    case quarter = "90D"

    var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        }
    }
}

// MARK: - Real ViewModel

@MainActor
final class RealChartsViewModel: ChartsViewModelProtocol {
    @Published var temperatureReadings: [TemperatureReading] = []
    @Published var tideReadings: [TideReading] = []
    @Published var waveReadings: [WaveReading] = []
    @Published var waterQualityReadings: [WaterQualityReading] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedStation: String = "Monterey Bay" {
        didSet { Task { await fetchData(range: currentRange) } }
    }

    private var currentRange: TimeRange = .week

    var hasTemperatureData: Bool { selectedStation == "Monterey Bay" }

    private var stationId: String {
        switch selectedStation {
        case "Moss Landing": return "9413616"
        case "Santa Cruz":   return "9413745"
        default:             return "9413450"
        }
    }

    private var stationCoordinate: (lat: Double, lon: Double) {
        switch selectedStation {
        case "Moss Landing": return (36.8027, -121.7874)
        case "Santa Cruz":   return (36.9618, -122.0183)
        default:             return (36.6050, -121.8886)
        }
    }

    func fetchData(range: TimeRange) async {
        currentRange = range
        isLoading = true
        errorMessage = nil
        temperatureReadings = []
        tideReadings = []
        waveReadings = []
        waterQualityReadings = []

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String) -> Date {
            formatter.date(from: str) ?? fallback.date(from: str) ?? Date()
        }

        if hasTemperatureData {
            do {
                let readings = try await CoastalAPIClient.shared.fetchReadings(
                    forStation: stationId, days: range.days)
                temperatureReadings = readings.map {
                    TemperatureReading(date: parseDate($0.recordedAt),
                                       value: $0.temperature,
                                       isAnomaly: $0.isAnomaly)
                }
                tideReadings = readings.map {
                    TideReading(date: parseDate($0.recordedAt), value: $0.tideHeight)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            do {
                let coord = stationCoordinate
                let marine = try await CoastalAPIClient.shared.fetchMarineReadings(
                    latitude: coord.lat, longitude: coord.lon)

                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm"

                waveReadings = marine.compactMap { r in
                    guard let wh = r.waveHeight, let date = df.date(from: r.time) else { return nil }
                    return WaveReading(date: date, value: wh)
                }
                tideReadings = marine.compactMap { r in
                    guard let sst = r.seaSurfaceTemperature, let date = df.date(from: r.time) else { return nil }
                    return TideReading(date: date, value: sst)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Main View

struct ChartsView: View {
    @StateObject private var viewModel = RealChartsViewModel()
    @State private var selectedRange: TimeRange = .week

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ecBackground.ignoresSafeArea()
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else {
                        chartsScrollView
                    }
                }
            }
            .task { await viewModel.fetchData(range: selectedRange) }
            .onChange(of: selectedRange) { _, newRange in
                Task { await viewModel.fetchData(range: newRange) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Subviews

    private var chartsScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Charts")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ecSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                // Station picker
                Menu {
                    ForEach(["Monterey Bay", "Moss Landing", "Santa Cruz"], id: \.self) { station in
                        Button(station) { viewModel.selectedStation = station }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(Color.ecSecondary)
                        Text(viewModel.selectedStation)
                            .foregroundStyle(Color.ecText)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.ecMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.ecSecondary, lineWidth: 1.8))
                    )
                    .shadow(color: Color.ecSecondary.opacity(0.12), radius: 5, y: 2)
                }

                timeRangePicker.padding(.horizontal, 16)

                // Show different charts based on station
                if viewModel.hasTemperatureData {
                    // Monterey — temperature + tide
                    TemperatureChartCard(readings: viewModel.temperatureReadings, range: selectedRange)
                    TideChartCard(
                        readings: viewModel.tideReadings,
                        range: selectedRange,
                        title: "Tide Level",
                        subtitle: "Meters above MLLW",
                        unit: "m"
                    )
                } else {
                    // Moss Landing / Santa Cruz — sea temp + wave height
                    TideChartCard(
                        readings: viewModel.tideReadings,
                        range: selectedRange,
                        title: "Sea Surface Temperature",
                        subtitle: "°C from Open-Meteo Marine",
                        unit: "°C"
                    )
                    WaveChartCard(readings: viewModel.waveReadings, range: selectedRange)

                    // Info banner
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.ecSecondary)
                        Text("NOAA water temperature unavailable at this station. Showing Open-Meteo marine forecast.")
                            .font(.caption)
                            .foregroundStyle(Color.ecSecondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ecSecondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollContentBackground(.hidden)
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(Color.ecPrimary)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Color.ecPrimary)
            Text("Loading readings…")
                .foregroundStyle(Color.ecText)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "Couldn't Load Data",
            systemImage: "antenna.radiowaves.left.and.right.slash",
            description: Text(message)
        )
    }
}

// MARK: - Chart Cards

struct TemperatureChartCard: View {
    let readings: [TemperatureReading]
    let range: TimeRange

    private var rollingAverage: Double {
        guard !readings.isEmpty else { return 0 }
        return readings.map(\.value).reduce(0, +) / Double(readings.count)
    }

    private var anomalyCount: Int { readings.filter(\.isAnomaly).count }

    var body: some View {
        ChartCard(
            title: "Water Temperature",
            subtitle: "°C · \(anomalyCount) anomal\(anomalyCount == 1 ? "y" : "ies") detected"
        ) {
            Chart {
                RuleMark(y: .value("Avg", rollingAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.ecMuted)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(String(format: "%.1f°", rollingAverage))
                            .font(.caption2)
                            .foregroundStyle(Color.ecMuted)
                    }

                ForEach(readings) { reading in
                    LineMark(
                        x: .value("Date", reading.date),
                        y: .value("Temp", reading.value)
                    )
                    .foregroundStyle(Color.ecPrimary.gradient)
                    .interpolationMethod(.catmullRom)

                    if reading.isAnomaly {
                        PointMark(
                            x: .value("Date", reading.date),
                            y: .value("Temp", reading.value)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(60)
                        .annotation(position: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.ecMuted.opacity(0.3))
                    AxisTick()
                    if let number = value.as(Double.self) {
                        AxisValueLabel {
                            Text(number.formatted(.number.precision(.fractionLength(0...1))))
                                .foregroundStyle(Color.ecText)
                        }
                    }
                }
            }
            .chartYAxisLabel("°C", alignment: .trailing)
        }
    }
}

struct TideChartCard: View {
    let readings: [TideReading]
    let range: TimeRange
    var title: String = "Tide Level"
    var subtitle: String = "Meters above MLLW"
    var unit: String = "m"

    var body: some View {
        ChartCard(title: title, subtitle: subtitle) {
            Chart(readings) { reading in
                AreaMark(
                    x: .value("Date", reading.date),
                    y: .value("Value", reading.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [Color.ecSecondary.opacity(0.35), Color.ecSecondary.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Value", reading.value)
                )
                .foregroundStyle(Color.ecSecondary)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.ecMuted.opacity(0.3))
                    AxisTick()
                    AxisValueLabel().foregroundStyle(Color.ecText)
                }
            }
            .chartYAxisLabel(unit, alignment: .trailing)
        }
    }
}

struct WaveChartCard: View {
    let readings: [WaveReading]
    let range: TimeRange

    private var maxWave: Double { readings.map(\.value).max() ?? 0 }

    var body: some View {
        ChartCard(
            title: "Wave Height",
            subtitle: String(format: "Significant height · Peak %.1f m", maxWave)
        ) {
            Chart(readings) { reading in
                BarMark(
                    x: .value("Date", reading.date),
                    y: .value("Wave", reading.value)
                )
                .foregroundStyle(Color.ecWave.opacity(0.5 + (reading.value / max(maxWave, 1)) * 0.5))
                .cornerRadius(2)
            }
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.ecMuted.opacity(0.3))
                    AxisTick()
                    AxisValueLabel().foregroundStyle(Color.ecText)
                }
            }
            .chartYAxisLabel("m", alignment: .trailing)
        }
    }
}

// MARK: - Reusable Chart Card Shell

struct ChartCard<ChartContent: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let chart: () -> ChartContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ecText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.ecSecondaryText)
            }
            chart().frame(height: 180)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.ecSecondary, lineWidth: 1.8))
        )
        .shadow(color: Color.ecSecondary.opacity(0.25), radius: 8, y: 3)
        .padding(.horizontal, 16)
    }
}

// MARK: - Shared X-Axis Helper

@AxisContentBuilder
private func chartXAxis(for range: TimeRange) -> some AxisContent {
    switch range {
    case .week:
        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
        }
    case .month:
        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    case .quarter:
        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Preview

#Preview {
    ChartsView()
}
