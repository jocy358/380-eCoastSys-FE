//
//  ChartsView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//  Worked on by Lily S on 05/04/26

import SwiftUI
import Combine
import Charts

// MARK: - Data Models

struct TemperatureReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double       // °C
    let isAnomaly: Bool
}

struct TideReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double       // meters MLLW
}

struct WaveReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double       // meters significant wave height
}

struct WaterQualityReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double       // 0–100 index
}

// MARK: - ViewModel Protocol
// Wire this up to your CoastalAPIClient when ready.

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
    case week  = "7D"
    case month = "30D"
    case quarter = "90D"

    var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        }
    }
}

// MARK: - Mock ViewModel (replace with your real one)

@MainActor
final class MockChartsViewModel: ChartsViewModelProtocol {
    @Published var temperatureReadings: [TemperatureReading] = []
    @Published var tideReadings: [TideReading] = []
    @Published var waveReadings: [WaveReading] = []
    @Published var waterQualityReadings: [WaterQualityReading] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedStation: String = "Monterey Bay"

    func fetchData(range: TimeRange) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 600_000_000) // simulate network

        let now = Date()
        let calendar = Calendar.current
        let count = range.days * 4 // every 6 hours

        temperatureReadings = (0..<count).map { i in
            let date = calendar.date(byAdding: .hour, value: -(count - i) * 6, to: now)!
            let base = 14.0 + sin(Double(i) / 12) * 2.5
            let noise = Double.random(in: -0.6...0.6)
            let isAnomaly = i == count / 3 || i == count * 2 / 3
            let value = isAnomaly ? base + Double.random(in: 4...6) : base + noise
            return TemperatureReading(date: date, value: value, isAnomaly: isAnomaly)
        }

        tideReadings = (0..<count).map { i in
            let date = calendar.date(byAdding: .hour, value: -(count - i) * 6, to: now)!
            let value = sin(Double(i) / 2.0 * .pi / 6) * 0.9 + 0.9 + Double.random(in: -0.1...0.1)
            return TideReading(date: date, value: value)
        }

        waveReadings = (0..<count).map { i in
            let date = calendar.date(byAdding: .hour, value: -(count - i) * 6, to: now)!
            let value = max(0.2, 1.8 + sin(Double(i) / 8) * 1.2 + Double.random(in: -0.3...0.3))
            return WaveReading(date: date, value: value)
        }

        waterQualityReadings = (0..<count).map { i in
            let date = calendar.date(byAdding: .hour, value: -(count - i) * 6, to: now)!
            let value = min(100, max(0, 78 + sin(Double(i) / 10) * 12 + Double.random(in: -5...5)))
            return WaterQualityReading(date: date, value: value)
        }

        isLoading = false
    }
}

// MARK: - Main View

struct ChartsView: View {
    @StateObject private var viewModel = MockChartsViewModel()
    // To use your real ViewModel, replace with:
    // @StateObject private var viewModel: YourChartsViewModel
    // and inject it via init or @EnvironmentObject

    @State private var selectedRange: TimeRange = .week

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    chartsScrollView
                }
            }
            .navigationTitle("Charts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Swap out for your real station list
                        ForEach(["Monterey Bay", "Moss Landing", "Santa Cruz"], id: \.self) { station in
                            Button(station) { viewModel.selectedStation = station }
                        }
                    } label: {
                        Label(viewModel.selectedStation, systemImage: "location.circle")
                            .font(.subheadline)
                    }
                }
            }
            .task { await viewModel.fetchData(range: selectedRange) }
            .onChange(of: selectedRange) { _, newRange in
                Task { await viewModel.fetchData(range: newRange) }
            }
        }
    }

    // MARK: - Subviews

    private var chartsScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                timeRangePicker
                    .padding(.horizontal)

                TemperatureChartCard(readings: viewModel.temperatureReadings, range: selectedRange)
                TideChartCard(readings: viewModel.tideReadings, range: selectedRange)
                WaveChartCard(readings: viewModel.waveReadings, range: selectedRange)
                WaterQualityChartCard(readings: viewModel.waterQualityReadings, range: selectedRange)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading readings…")
                .foregroundStyle(.secondary)
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

    private var anomalyCount: Int {
        readings.filter(\.isAnomaly).count
    }

    var body: some View {
        ChartCard(
            title: "Water Temperature",
            subtitle: "°C · \(anomalyCount) anomal\(anomalyCount == 1 ? "y" : "ies") detected",
            accentColor: .ecPrimary
        ) {
            Chart {
                // Rolling average rule
                RuleMark(y: .value("Avg", rollingAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(String(format: "%.1f°", rollingAverage))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                    AxisGridLine()
                    AxisTick()
                    if let number = value.as(Double.self) {
                        AxisValueLabel {
                            Text(number.formatted(.number.precision(.fractionLength(0...1))))
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

    var body: some View {
        ChartCard(
            title: "Tide Level",
            subtitle: "Meters above MLLW",
            accentColor: .ecSecondary
        ) {
            Chart(readings) { reading in
                AreaMark(
                    x: .value("Date", reading.date),
                    y: .value("Tide", reading.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.ecSecondary.opacity(0.4), Color.ecSecondary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Tide", reading.value)
                )
                .foregroundStyle(Color.ecSecondary)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxisLabel("m", alignment: .trailing)
        }
    }
}

struct WaveChartCard: View {
    let readings: [WaveReading]
    let range: TimeRange

    private var maxWave: Double {
        readings.map(\.value).max() ?? 0
    }

    var body: some View {
        ChartCard(
            title: "Wave Height",
            subtitle: String(format: "Significant height · Peak %.1f m", maxWave),
            accentColor: .ecWave
        ) {
            Chart(readings) { reading in
                BarMark(
                    x: .value("Date", reading.date),
                    y: .value("Wave", reading.value)
                )
                .foregroundStyle(
                    Color.ecWave.opacity(
                        0.5 + (reading.value / max(maxWave, 1)) * 0.5
                    )
                )
                .cornerRadius(2)
            }
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxisLabel("m", alignment: .trailing)
        }
    }
}

struct WaterQualityChartCard: View {
    let readings: [WaterQualityReading]
    let range: TimeRange

    private var latestQuality: Double {
        readings.last?.value ?? 0
    }

    private var qualityLabel: String {
        switch latestQuality {
        case 80...: return "Good"
        case 60..<80: return "Fair"
        default: return "Poor"
        }
    }

    private var qualityColor: Color {
        switch latestQuality {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    var body: some View {
        ChartCard(
            title: "Water Quality Index",
            subtitle: "0–100 · Currently \(qualityLabel)",
            accentColor: qualityColor
        ) {
            Chart(readings) { reading in
                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Quality", reading.value)
                )
                .foregroundStyle(qualityColor.gradient)
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Date", reading.date),
                    y: .value("Quality", reading.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [qualityColor.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { eCoastSys.chartXAxis(for: range) }
            .chartYAxisLabel("Index", alignment: .trailing)
            // Threshold zones
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Color.red.opacity(0.04)        // 0–60 poor
                        .frame(maxHeight: .infinity)
                    Color.orange.opacity(0.04)     // 60–80 fair
                        .frame(maxHeight: .infinity)
                    Color.green.opacity(0.04)      // 80–100 good
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Reusable Chart Card Shell

struct ChartCard<ChartContent: View>: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    @ViewBuilder let chart: () -> ChartContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            chart()
                .frame(height: 180)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
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

// MARK: - Color Extensions
// Add these to your existing Color+Extensions file or Assets.xcassets.
// If you already have ecPrimary defined, remove the duplicates here.
//extension Color {
//    static let ecPrimary = Color(hue: 0.56, saturation: 0.65, brightness: 0.65)
//    static let ecSecondary = Color(hue: 0.58, saturation: 0.30, brightness: 0.75)
//    static let ecWave = Color(hue: 0.58, saturation: 0.55, brightness: 0.70) // add this
//}

// MARK: - Preview

#Preview {
    ChartsView()
}

