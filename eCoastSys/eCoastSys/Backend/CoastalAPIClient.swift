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


class CoastalAPIClient {
    static let shared = CoastalAPIClient()
    private let baseURL = "https://380-ecoastsys-be-production.up.railway.app/api"

    func fetchReadings() async throws -> [WaterReadingDTO] {
        let url = URL(string: "\(baseURL)/readings")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([WaterReadingDTO].self, from: data)
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
}
