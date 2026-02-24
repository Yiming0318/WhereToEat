//
//  CandidateRestaurant.swift
//  WhereToEat
//

import Foundation

enum CandidateSource: Hashable {
    case saved
    case nearby
}

struct CandidateRestaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let cuisines: [String]
    let priceLevel: Int?
    let distanceMiles: Double?
    let latitude: Double?
    let longitude: Double?
    let source: CandidateSource
    let savedRestaurantId: UUID?
    let lastVisited: Date?
    let visitCount: Int
    let isFavorite: Bool
    let isNew: Bool
    let userRating: Int?

    static func fromSaved(_ r: Restaurant) -> CandidateRestaurant {
        CandidateRestaurant(
            id: "saved|\(r.id.uuidString.lowercased())",
            name: r.name,
            cuisines: r.cuisines,
            priceLevel: r.priceLevel,
            distanceMiles: r.distanceMiles,
            latitude: nil,
            longitude: nil,
            source: .saved,
            savedRestaurantId: r.id,
            lastVisited: r.lastVisited,
            visitCount: r.visitCount,
            isFavorite: r.isFavorite,
            isNew: r.isNew,
            userRating: r.userRating
        )
    }

    static func fromNearby(
        name: String,
        lat: Double,
        lon: Double,
        distanceMiles: Double?
    ) -> CandidateRestaurant {
        let normalized = normalizedName(name)
        let latRounded = roundedCoordinateString(lat)
        let lonRounded = roundedCoordinateString(lon)

        return CandidateRestaurant(
            id: "\(normalized)|\(latRounded)|\(lonRounded)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            cuisines: [],
            priceLevel: nil,
            distanceMiles: distanceMiles,
            latitude: lat,
            longitude: lon,
            source: .nearby,
            savedRestaurantId: nil,
            lastVisited: nil,
            visitCount: 0,
            isFavorite: false,
            isNew: true,
            userRating: nil
        )
    }

    private static func normalizedName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func roundedCoordinateString(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}

