//
//  NearbySearchService.swift
//  WhereToEat
//

import Foundation
import CoreLocation
import MapKit

enum NearbySearchError: LocalizedError {
    case locationServicesDisabled
    case permissionDenied
    case locationUnavailable
    case timedOut

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location Services are disabled. Enable them in Settings to scan nearby restaurants."
        case .permissionDenied:
            return "Location permission is denied or restricted. Allow While Using App access to scan nearby restaurants."
        case .locationUnavailable:
            return "Current location is unavailable. Try again in a moment."
        case .timedOut:
            return "Nearby scan timed out. Check location permission/simulator location and try again."
        }
    }
}

@MainActor
final class NearbySearchService {
    func fetchNearbyRestaurants(radiusMiles: Double) async throws -> [CandidateRestaurant] {
        let locator = LocationAuthorizationAndFixProvider()
        let userLocation = try await locator.requestCurrentLocation()

        let meters = max(radiusMiles, 0.25) * 1_609.344
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: meters * 2,
            longitudinalMeters: meters * 2
        )

        let response = try await MKLocalSearch(request: request).start()

        let candidates = response.mapItems.compactMap { item -> CandidateRestaurant? in
            let coordinate = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate), let name = item.name, !name.isEmpty else {
                return nil
            }

            let itemLocation = item.placemark.location ?? CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distanceMiles = userLocation.distance(from: itemLocation) / 1_609.344

            return CandidateRestaurant.fromNearby(
                name: name,
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                distanceMiles: distanceMiles
            )
        }

        return dedupedCandidates(candidates)
    }

    private func dedupedCandidates(_ candidates: [CandidateRestaurant]) -> [CandidateRestaurant] {
        var seen = Set<String>()
        var output: [CandidateRestaurant] = []
        output.reserveCapacity(candidates.count)

        for candidate in candidates where seen.insert(candidate.id).inserted {
            output.append(candidate)
        }

        return output
    }
}

@MainActor
private final class LocationAuthorizationAndFixProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let authorizationTimeoutSeconds: UInt64 = 12
    private let locationTimeoutSeconds: UInt64 = 12

    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationTimeoutTask: Task<Void, Never>?
    private var locationTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw NearbySearchError.locationServicesDisabled
        }

        try await ensureAuthorized()

        if let location = manager.location {
            return location
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            startLocationTimeout()
            manager.requestLocation()
        }
    }

    private func ensureAuthorized() async throws {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied, .restricted:
            throw NearbySearchError.permissionDenied
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                startAuthorizationTimeout()
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            throw NearbySearchError.permissionDenied
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationContinuation = nil
            authorizationTimeoutTask?.cancel()
            authorizationTimeoutTask = nil
            continuation.resume()
        case .denied, .restricted:
            authorizationContinuation = nil
            authorizationTimeoutTask?.cancel()
            authorizationTimeoutTask = nil
            continuation.resume(throwing: NearbySearchError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation = nil
            authorizationTimeoutTask?.cancel()
            authorizationTimeoutTask = nil
            continuation.resume(throwing: NearbySearchError.permissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        if let location = locations.last {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: NearbySearchError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                continuation.resume(throwing: NearbySearchError.permissionDenied)
                return
            case .locationUnknown:
                continuation.resume(throwing: NearbySearchError.locationUnavailable)
                return
            default:
                break
            }
        }

        continuation.resume(throwing: NearbySearchError.locationUnavailable)
    }

    private func startAuthorizationTimeout() {
        authorizationTimeoutTask?.cancel()
        authorizationTimeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.authorizationTimeoutSeconds * 1_000_000_000)
            guard let continuation = self.authorizationContinuation else { return }
            self.authorizationContinuation = nil
            continuation.resume(throwing: NearbySearchError.timedOut)
        }
    }

    private func startLocationTimeout() {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.locationTimeoutSeconds * 1_000_000_000)
            guard let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            continuation.resume(throwing: NearbySearchError.timedOut)
        }
    }
}
