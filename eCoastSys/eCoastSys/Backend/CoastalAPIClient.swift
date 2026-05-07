//
//  CoastalAPIClient.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import Foundation

struct WaterReadingDTO: Codable, Identifiable {
    let id: String
    let stationId: String
    let temperature: Double
    let tideHeight: Double
    let qualityIndex: Int
    let isAnomaly: Bool
    let recordedAt: String
}

struct SpeciesSightingDTO: Codable, Identifiable {
    let id: String
    let speciesName: String
    let scientificName: String
    let group: String
    let count: Int
    let latitude: Double
    let longitude: Double
    let sightedAt: String
}

struct MarineReadingDTO: Codable, Identifiable {
    var id: String { time }
    let time: String
    let waveHeight: Double?
    let waveDirection: Int?
    let wavePeriod: Double?
    let seaSurfaceTemperature: Double?
}

class CoastalAPIClient {
    static let shared = CoastalAPIClient()
    private let baseURL = "https://380-ecoastsys-be-production.up.railway.app/api"

    func fetchReadings() async throws -> [WaterReadingDTO] {
        let url = URL(string: "\(baseURL)/readings")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([WaterReadingDTO].self, from: data)
    }

    func fetchSpecies() async throws -> [SpeciesSightingDTO] {
        let url = URL(string: "\(baseURL)/species")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([SpeciesSightingDTO].self, from: data)
    }

    func fetchAnomalies() async throws -> [WaterReadingDTO] {
        let url = URL(string: "\(baseURL)/anomalies")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([WaterReadingDTO].self, from: data)
    }

    func fetchAnomalies(forStation stationId: String) async throws -> [WaterReadingDTO] {
        let url = URL(string: "\(baseURL)/anomalies?stationId=\(stationId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([WaterReadingDTO].self, from: data)
    }

    func fetchReadings(forStation stationId: String, days: Int = 1) async throws -> [WaterReadingDTO] {
        let url = URL(string: "\(baseURL)/readings?stationId=\(stationId)&days=\(days)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([WaterReadingDTO].self, from: data)
    }

    func fetchSpecies(group: String? = nil) async throws -> [SpeciesSightingDTO] {
        var urlString = "\(baseURL)/species"
        if let group = group { urlString += "?group=\(group)" }
        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([SpeciesSightingDTO].self, from: data)
    }

    func fetchMarineReadings(latitude: Double, longitude: Double) async throws -> [MarineReadingDTO] {
        let urlString = "https://marine-api.open-meteo.com/v1/marine"
            + "?latitude=\(latitude)"
            + "&longitude=\(longitude)"
            + "&hourly=wave_height,wave_direction,wave_period,sea_surface_temperature"
            + "&forecast_days=1"
            + "&timezone=America%2FLos_Angeles"
        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct OpenMeteoResponse: Codable {
            let hourly: HourlyData
            struct HourlyData: Codable {
                let time: [String]
                let waveHeight: [Double?]
                let waveDirection: [Int?]
                let wavePeriod: [Double?]
                let seaSurfaceTemperature: [Double?]
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenMeteoResponse.self, from: data)

        return zip(response.hourly.time.indices, response.hourly.time).map { i, time in
            MarineReadingDTO(
                time: time,
                waveHeight: response.hourly.waveHeight[i],
                waveDirection: response.hourly.waveDirection[i],
                wavePeriod: response.hourly.wavePeriod[i],
                seaSurfaceTemperature: response.hourly.seaSurfaceTemperature[i]
            )
        }
    }
}
