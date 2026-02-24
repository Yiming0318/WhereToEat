//
//  AppState.swift
//  WhereToEat
//

import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var includeNearby: Bool = false
    @Published var onlyNearby: Bool = false
    @Published var nearbyRadiusMiles: Double = 2
    @Published var nearbyCandidates: [CandidateRestaurant] = []
    @Published var nearbyLastUpdated: Date? = nil
    @Published var requestedRestaurantEditorId: UUID? = nil

    var nearbyIsFresh: Bool {
        guard let nearbyLastUpdated else { return false }
        return Date().timeIntervalSince(nearbyLastUpdated) <= 10 * 60
    }

    func clearNearby() {
        nearbyCandidates = []
        nearbyLastUpdated = nil
    }
}
