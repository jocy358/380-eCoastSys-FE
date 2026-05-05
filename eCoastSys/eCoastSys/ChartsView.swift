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

// MARK: - Mock ViewModel

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
        try? await Task.sleep(nanoseconds: 600_000_000)

        let now = Date()
        let calendar = Calendar.current
        let count = range.days * 4

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

                // Title header — matches SpeciesView / MapView style
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.ecSecondary, lineWidth: 1.8)
                            )
                    )
                    .shadow(color: Color.ecSecondary.opacity(0.12), radius: 5, y: 2)
                }

                // Time range segmented picker styled to match theme
                timeRangePicker
                    .padding(.horizontal, 16)

                TemperatureChartCard(readings: viewModel.temperatureReadings, range: selectedRange)
                TideChartCard(readings: viewModel.tideReadings, range: selectedRange)
                WaveChartCard(readings: viewModel.waveReadings, range: selectedRange)
                WaterQualityChartCard(readings: viewModel.waterQualityReadings, range: selectedRange)
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
            ProgressView()
                .tint(Color.ecPrimary)
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

    private var anomalyCount: Int {
        readings.filter(\.isAnomaly).count
    }

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

    var body: some View {
        ChartCard(title: "Tide Level", subtitle: "Meters above MLLW") {
            Chart(readings) { reading in
                AreaMark(
                    x: .value("Date", reading.date),
                    y: .value("Tide", reading.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.ecSecondary.opacity(0.35), Color.ecSecondary.opacity(0.05)],
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

struct WaveChartCard: View {
    let readings: [WaveReading]
    let range: TimeRange

    private var maxWave: Double {
        readings.map(\.value).max() ?? 0
    }

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
                .foregroundStyle(
                    Color.ecWave.opacity(
                        0.5 + (reading.value / max(maxWave, 1)) * 0.5
                    )
                )
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
            subtitle: "0–100 · Currently \(qualityLabel)"
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
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.ecMuted.opacity(0.3))
                    AxisTick()
                    AxisValueLabel().foregroundStyle(Color.ecText)
                }
            }
            .chartYAxisLabel("Index", alignment: .trailing)
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Color.red.opacity(0.04)
                        .frame(maxHeight: .infinity)
                    Color.orange.opacity(0.04)
                        .frame(maxHeight: .infinity)
                    Color.green.opacity(0.04)
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

            chart()
                .frame(height: 180)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.ecSecondary, lineWidth: 1.8)
                )
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
