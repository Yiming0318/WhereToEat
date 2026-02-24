//
//  WhereToEatTests.swift
//  WhereToEatTests
//
//  Created by YIMING GE on 2/23/26.
//

import XCTest
@testable import WhereToEat

final class WhereToEatTests: XCTestCase {
    private let engine = PickerEngine()

    func testAntiRepeatExcludesRestaurantsVisitedWithin7Days() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let blocked = restaurant(name: "Recent", cuisines: ["Thai"])
        let allowedA = restaurant(name: "Allowed A", cuisines: ["Thai"])
        let allowedB = restaurant(name: "Allowed B", cuisines: ["Thai"])
        let allowedC = restaurant(name: "Allowed C", cuisines: ["Thai"])

        let visits = [
            Visit(restaurantId: blocked.id, date: now.addingTimeInterval(-2 * 86_400), rating: 1)
        ]

        var rng = SeededRNG(seed: 42)
        let picks = engine.top3Picks(
            selectedCuisines: [],
            maxDistanceMiles: nil,
            noveltyMode: .balanced,
            vetoedRestaurantIds: [],
            visits: visits,
            restaurants: [blocked, allowedA, allowedB, allowedC],
            now: now,
            rng: &rng
        )

        XCTAssertFalse(picks.map(\.id).contains(blocked.id))
    }

    func testReturnsDistinctResults() {
        let restaurants = (0..<8).map { idx in
            restaurant(
                name: "R\(idx)",
                cuisines: idx.isMultiple(of: 2) ? ["Japanese"] : ["Mexican"],
                isNew: idx < 3,
                lastVisited: Date(timeIntervalSinceReferenceDate: 1_000_000 - Double(idx * 86_400))
            )
        }
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        var rng = SeededRNG(seed: 7)
        let picks = engine.top3Picks(
            selectedCuisines: [],
            maxDistanceMiles: nil,
            noveltyMode: .balanced,
            vetoedRestaurantIds: [],
            visits: [],
            restaurants: restaurants,
            now: now,
            rng: &rng
        )

        XCTAssertEqual(picks.count, 3)
        XCTAssertEqual(Set(picks.map(\.id)).count, 3)
    }

    func testAdventureModeIncreasesNewRestaurantSelectionWithSeededRNG() {
        let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
        let restaurants = makeNoveltyBiasFixture(now: now)

        var safeRNG = SeededRNG(seed: 12345)
        var adventureRNG = SeededRNG(seed: 12345)
        var safeNewPickCount = 0
        var adventureNewPickCount = 0

        for _ in 0..<200 {
            let safePicks = engine.top3Picks(
                selectedCuisines: [],
                maxDistanceMiles: nil,
                noveltyMode: .safe,
                vetoedRestaurantIds: [],
                visits: [],
                restaurants: restaurants,
                now: now,
                rng: &safeRNG
            )
            safeNewPickCount += safePicks.filter(\.isNew).count

            let adventurePicks = engine.top3Picks(
                selectedCuisines: [],
                maxDistanceMiles: nil,
                noveltyMode: .adventure,
                vetoedRestaurantIds: [],
                visits: [],
                restaurants: restaurants,
                now: now,
                rng: &adventureRNG
            )
            adventureNewPickCount += adventurePicks.filter(\.isNew).count
        }

        XCTAssertGreaterThan(
            adventureNewPickCount,
            safeNewPickCount,
            "Adventure mode should favor new restaurants more often than safe mode."
        )
    }
}

private extension WhereToEatTests {
    func makeNoveltyBiasFixture(now: Date) -> [Restaurant] {
        let newRestaurants = (0..<4).map { idx in
            restaurant(
                name: "New \(idx)",
                cuisines: ["Japanese"],
                isNew: true,
                lastVisited: nil,
                userRating: nil
            )
        }

        let olderRestaurants = (0..<6).map { idx in
            restaurant(
                name: "Old \(idx)",
                cuisines: ["Japanese"],
                isNew: false,
                lastVisited: now.addingTimeInterval(-Double((idx + 1) * 86_400)),
                userRating: nil
            )
        }

        return newRestaurants + olderRestaurants
    }

    func restaurant(
        name: String,
        cuisines: [String],
        isNew: Bool = false,
        lastVisited: Date? = nil,
        userRating: Int? = nil
    ) -> Restaurant {
        Restaurant(
            name: name,
            cuisines: cuisines,
            priceLevel: 2,
            distanceMiles: 2.0,
            isFavorite: false,
            isNew: isNew,
            lastVisited: lastVisited,
            visitCount: 0,
            userRating: userRating
        )
    }
}

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
