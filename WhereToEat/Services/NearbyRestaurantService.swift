//
//  NearbyRestaurantService.swift
//  WhereToEat
//

import Foundation
import CoreLocation
import MapKit

struct NearbyRestaurantScanRequest: Hashable {
    let centerLatitudeBucket: Int
    let centerLongitudeBucket: Int
    let radiusMilesBucket: Int

    init(center: CLLocationCoordinate2D, radiusMiles: Double) {
        // Round the center to reduce cache churn when location jitters slightly.
        centerLatitudeBucket = Int((center.latitude * 1_000).rounded())
        centerLongitudeBucket = Int((center.longitude * 1_000).rounded())
        radiusMilesBucket = Int((radiusMiles * 10).rounded())
    }
}

@MainActor
final class NearbyRestaurantCache {
    static let ttl: TimeInterval = 10 * 60

    private struct Entry {
        let fetchedAt: Date
        let results: [CandidateRestaurant]
    }

    private var entries: [NearbyRestaurantScanRequest: Entry] = [:]

    func cachedResults(
        for request: NearbyRestaurantScanRequest,
        now: Date = .now
    ) -> [CandidateRestaurant]? {
        guard let entry = entries[request] else { return nil }
        guard now.timeIntervalSince(entry.fetchedAt) <= Self.ttl else {
            entries.removeValue(forKey: request)
            return nil
        }
        return entry.results
    }

    func store(
        _ results: [CandidateRestaurant],
        for request: NearbyRestaurantScanRequest,
        now: Date = .now
    ) {
        entries[request] = Entry(fetchedAt: now, results: results)
    }

    func clearExpired(now: Date = .now) {
        entries = entries.filter { now.timeIntervalSince($0.value.fetchedAt) <= Self.ttl }
    }
}

@MainActor
final class NearbyRestaurantService {
    private let cache: NearbyRestaurantCache

    init(cache: NearbyRestaurantCache? = nil) {
        self.cache = cache ?? NearbyRestaurantCache()
    }

    func cachedCandidates(
        center: CLLocationCoordinate2D,
        radiusMiles: Double,
        now: Date = .now
    ) -> [CandidateRestaurant]? {
        let request = NearbyRestaurantScanRequest(center: center, radiusMiles: radiusMiles)
        return cache.cachedResults(for: request, now: now)
    }

    func scanNearbyRestaurants(
        center: CLLocationCoordinate2D,
        radiusMiles: Double,
        now: Date = .now
    ) async throws -> [CandidateRestaurant] {
        let request = NearbyRestaurantScanRequest(center: center, radiusMiles: radiusMiles)
        if let cached = cache.cachedResults(for: request, now: now) {
            return cached
        }

        // Step 1 scaffold: MapKit search integration comes next.
        let results: [CandidateRestaurant] = []
        cache.store(results, for: request, now: now)
        return results
    }
}
