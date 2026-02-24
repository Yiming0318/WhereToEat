//
//  Restaurant.swift
//  WhereToEat
//

import Foundation
import SwiftData

@Model
final class Restaurant {
    @Attribute(.unique) var id: UUID
    var name: String
    var cuisines: [String]
    var priceLevel: Int
    var distanceMiles: Double?
    var isFavorite: Bool
    var isNew: Bool
    var lastVisited: Date?
    var visitCount: Int
    var userRating: Int?

    init(
        id: UUID = UUID(),
        name: String = "",
        cuisines: [String] = [],
        priceLevel: Int = 1,
        distanceMiles: Double? = nil,
        isFavorite: Bool = false,
        isNew: Bool = true,
        lastVisited: Date? = nil,
        visitCount: Int = 0,
        userRating: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.cuisines = cuisines
        self.priceLevel = min(max(priceLevel, 1), 4)
        self.distanceMiles = distanceMiles
        self.isFavorite = isFavorite
        self.isNew = isNew
        self.lastVisited = lastVisited
        self.visitCount = max(visitCount, 0)
        self.userRating = Self.normalizedRating(userRating)
    }

    private static func normalizedRating(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return [-1, 0, 1].contains(value) ? value : nil
    }
}
