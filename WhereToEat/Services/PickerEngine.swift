//
//  PickerEngine.swift
//  WhereToEat
//

import Foundation

struct PickerEngine {
    enum NoveltyMode {
        case safe
        case balanced
        case adventure

        var noveltyMultiplier: Double {
            switch self {
            case .safe: return 0.5
            case .balanced: return 1.0
            case .adventure: return 1.9
            }
        }
    }

    func top3Picks(
        selectedCuisines: Set<String>,
        maxDistanceMiles: Double?,
        noveltyMode: NoveltyMode,
        vetoedRestaurantIds: Set<UUID>,
        visits: [Visit],
        restaurants: [Restaurant],
        now: Date = .now
    ) -> [Restaurant] {
        var rng = SystemRandomNumberGenerator()
        return top3Picks(
            selectedCuisines: selectedCuisines,
            maxDistanceMiles: maxDistanceMiles,
            noveltyMode: noveltyMode,
            vetoedRestaurantIds: vetoedRestaurantIds,
            visits: visits,
            restaurants: restaurants,
            now: now,
            rng: &rng
        )
    }

    func top3Picks(
        selectedCuisines: Set<String>,
        maxDistanceMiles: Double?,
        noveltyMode: NoveltyMode,
        vetoedRestaurantIds: Set<UUID>,
        visits: [Visit],
        candidates: [CandidateRestaurant],
        now: Date = .now
    ) -> [CandidateRestaurant] {
        var rng = SystemRandomNumberGenerator()
        return top3Picks(
            selectedCuisines: selectedCuisines,
            maxDistanceMiles: maxDistanceMiles,
            noveltyMode: noveltyMode,
            vetoedRestaurantIds: vetoedRestaurantIds,
            visits: visits,
            candidates: candidates,
            now: now,
            rng: &rng
        )
    }

    func top3Picks<R: RandomNumberGenerator>(
        selectedCuisines: Set<String>,
        maxDistanceMiles: Double?,
        noveltyMode: NoveltyMode,
        vetoedRestaurantIds: Set<UUID>,
        visits: [Visit],
        restaurants: [Restaurant],
        now: Date = .now,
        rng: inout R
    ) -> [Restaurant] {
        let normalizedSelectedCuisines = Set(selectedCuisines.map { $0.lowercased() })
        let restaurantsById = Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })

        let recentVisitCutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let recentCuisinePenaltyCutoff = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now

        let recentlyVisitedRestaurantIds = Set(
            visits.filter { $0.date >= recentVisitCutoff }.map(\.restaurantId)
        )

        let cuisinesEatenRecently = Set(
            visits
                .filter { $0.date >= recentCuisinePenaltyCutoff }
                .compactMap { restaurantsById[$0.restaurantId] }
                .flatMap(\.cuisines)
                .map { $0.lowercased() }
        )

        var candidates: [(restaurant: Restaurant, weight: Double)] = []
        candidates.reserveCapacity(restaurants.count)

        for restaurant in restaurants {
            guard !vetoedRestaurantIds.contains(restaurant.id) else { continue }
            guard !recentlyVisitedRestaurantIds.contains(restaurant.id) else { continue }

            if !normalizedSelectedCuisines.isEmpty {
                let restaurantCuisines = Set(restaurant.cuisines.map { $0.lowercased() })
                guard !restaurantCuisines.isDisjoint(with: normalizedSelectedCuisines) else { continue }
            }

            if let maxDistanceMiles, let distanceMiles = restaurant.distanceMiles, distanceMiles > maxDistanceMiles {
                continue
            }

            let score = score(
                restaurant: restaurant,
                cuisinesEatenRecently: cuisinesEatenRecently,
                noveltyMode: noveltyMode,
                now: now
            )
            let weight = max(0.05, score)
            candidates.append((restaurant, weight))
        }

        return weightedSampleWithoutReplacement(from: candidates, count: 3, rng: &rng)
    }

    func top3Picks<R: RandomNumberGenerator>(
        selectedCuisines: Set<String>,
        maxDistanceMiles: Double?,
        noveltyMode: NoveltyMode,
        vetoedRestaurantIds: Set<UUID>,
        visits: [Visit],
        candidates: [CandidateRestaurant],
        now: Date = .now,
        rng: inout R
    ) -> [CandidateRestaurant] {
        let normalizedSelectedCuisines = Set(selectedCuisines.map { $0.lowercased() })

        let recentVisitCutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let recentCuisinePenaltyCutoff = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now

        let recentlyVisitedRestaurantIds = Set(
            visits.filter { $0.date >= recentVisitCutoff }.map(\.restaurantId)
        )

        let candidatesBySavedId = [UUID: CandidateRestaurant](
            uniqueKeysWithValues: candidates.compactMap { candidate in
                guard let savedId = candidate.savedRestaurantId else { return nil }
                return (savedId, candidate)
            }
        )

        let cuisinesEatenRecently = Set(
            visits
                .filter { $0.date >= recentCuisinePenaltyCutoff }
                .compactMap { candidatesBySavedId[$0.restaurantId] }
                .flatMap { $0.cuisines }
                .map { $0.lowercased() }
        )

        var weightedCandidates: [(candidate: CandidateRestaurant, weight: Double)] = []
        weightedCandidates.reserveCapacity(candidates.count)

        for candidate in candidates {
            if let savedId = candidate.savedRestaurantId {
                guard !vetoedRestaurantIds.contains(savedId) else { continue }
                guard !recentlyVisitedRestaurantIds.contains(savedId) else { continue }
            }

            if !normalizedSelectedCuisines.isEmpty, !candidate.cuisines.isEmpty {
                let candidateCuisines = Set(candidate.cuisines.map { $0.lowercased() })
                guard !candidateCuisines.isDisjoint(with: normalizedSelectedCuisines) else { continue }
            }

            if let maxDistanceMiles, let distanceMiles = candidate.distanceMiles, distanceMiles > maxDistanceMiles {
                continue
            }

            let score = score(
                candidate: candidate,
                cuisinesEatenRecently: cuisinesEatenRecently,
                noveltyMode: noveltyMode,
                now: now
            )
            weightedCandidates.append((candidate, max(0.05, score)))
        }

        return weightedSampleWithoutReplacement(from: weightedCandidates, count: 3, rng: &rng)
    }

    @MainActor
    func buildCandidatePool(
        saved: [Restaurant],
        nearby: [CandidateRestaurant],
        includeNearby: Bool,
        onlyNearby: Bool
    ) -> [CandidateRestaurant] {
        let savedCandidates = saved.map(CandidateRestaurant.fromSaved)
        guard includeNearby else { return savedCandidates }
        guard !onlyNearby else { return nearby }

        let normalizedSavedNames = Set(savedCandidates.map { normalizedName($0.name) })
        let filteredNearby = nearby.filter { !normalizedSavedNames.contains(normalizedName($0.name)) }
        return savedCandidates + filteredNearby
    }

    private func score(
        restaurant: Restaurant,
        cuisinesEatenRecently: Set<String>,
        noveltyMode: NoveltyMode,
        now: Date
    ) -> Double {
        var score = 1.0

        if restaurant.isFavorite {
            score += 1.2
        }

        switch restaurant.userRating {
        case 1:
            score += 1.5
        case 0:
            score += 0.2
        case -1:
            score -= 1.6
        default:
            break
        }

        let normalizedRestaurantCuisines = Set(restaurant.cuisines.map { $0.lowercased() })
        if !normalizedRestaurantCuisines.isDisjoint(with: cuisinesEatenRecently) {
            score -= 1.0
        }

        let noveltyDays: Double = {
            guard let lastVisited = restaurant.lastVisited else { return 30 }
            return max(0, now.timeIntervalSince(lastVisited) / 86_400)
        }()

        var novelty = min(noveltyDays / 30.0, 1.5)
        if restaurant.isNew {
            novelty += 1.4
        }
        score += novelty * noveltyMode.noveltyMultiplier

        if restaurant.visitCount > 0 {
            score -= min(Double(restaurant.visitCount) * 0.03, 0.5)
        }

        return score
    }

    private func score(
        candidate: CandidateRestaurant,
        cuisinesEatenRecently: Set<String>,
        noveltyMode: NoveltyMode,
        now: Date
    ) -> Double {
        var score = 1.0

        if candidate.isFavorite {
            score += 1.2
        }

        switch candidate.userRating {
        case 1:
            score += 1.5
        case 0:
            score += 0.2
        case -1:
            score -= 1.6
        default:
            break
        }

        let normalizedCandidateCuisines = Set(candidate.cuisines.map { $0.lowercased() })
        if !normalizedCandidateCuisines.isDisjoint(with: cuisinesEatenRecently) {
            score -= 1.0
        }

        let noveltyDays: Double = {
            guard let lastVisited = candidate.lastVisited else { return 30 }
            return max(0, now.timeIntervalSince(lastVisited) / 86_400)
        }()

        var novelty = min(noveltyDays / 30.0, 1.5)
        if candidate.isNew {
            novelty += 1.4
        }
        score += novelty * noveltyMode.noveltyMultiplier

        if candidate.visitCount > 0 {
            score -= min(Double(candidate.visitCount) * 0.03, 0.5)
        }

        return score
    }

    private func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func weightedSampleWithoutReplacement<R: RandomNumberGenerator>(
        from candidates: [(restaurant: Restaurant, weight: Double)],
        count: Int,
        rng: inout R
    ) -> [Restaurant] {
        var remaining = candidates
        var picks: [Restaurant] = []
        picks.reserveCapacity(min(count, remaining.count))

        while picks.count < count, !remaining.isEmpty {
            let totalWeight = remaining.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else {
                picks.append(contentsOf: remaining.prefix(count - picks.count).map(\.restaurant))
                break
            }

            let threshold = Double.random(in: 0..<totalWeight, using: &rng)
            var cumulative = 0.0
            var selectedIndex = remaining.startIndex

            for index in remaining.indices {
                cumulative += remaining[index].weight
                if threshold < cumulative {
                    selectedIndex = index
                    break
                }
            }

            picks.append(remaining.remove(at: selectedIndex).restaurant)
        }

        return picks
    }

    private func weightedSampleWithoutReplacement<R: RandomNumberGenerator>(
        from candidates: [(candidate: CandidateRestaurant, weight: Double)],
        count: Int,
        rng: inout R
    ) -> [CandidateRestaurant] {
        var remaining = candidates
        var picks: [CandidateRestaurant] = []
        picks.reserveCapacity(min(count, remaining.count))

        while picks.count < count, !remaining.isEmpty {
            let totalWeight = remaining.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else {
                picks.append(contentsOf: remaining.prefix(count - picks.count).map(\.candidate))
                break
            }

            let threshold = Double.random(in: 0..<totalWeight, using: &rng)
            var cumulative = 0.0
            var selectedIndex = remaining.startIndex

            for index in remaining.indices {
                cumulative += remaining[index].weight
                if threshold < cumulative {
                    selectedIndex = index
                    break
                }
            }

            picks.append(remaining.remove(at: selectedIndex).candidate)
        }

        return picks
    }
}
