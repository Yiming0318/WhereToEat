//
//  Visit.swift
//  WhereToEat
//

import Foundation
import SwiftData

@Model
final class Visit {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var date: Date
    var rating: Int?

    init(
        id: UUID = UUID(),
        restaurantId: UUID = UUID(),
        date: Date = Date(),
        rating: Int? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.date = date
        self.rating = Self.normalizedRating(rating)
    }

    private static func normalizedRating(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return [-1, 0, 1].contains(value) ? value : nil
    }
}
