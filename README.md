# WhereToEat

A SwiftUI + SwiftData app for deciding where to eat.

It combines:
- your saved restaurant list
- visit history
- a weighted picker engine
- optional nearby restaurant discovery (Apple MapKit + CoreLocation)

## Features

- **Pick** tab
  - Cuisine multi-select
  - Distance filter
  - Novelty mode (Safe / Balanced / Adventure)
  - Optional Nearby scan (transient, cached in-memory for 10 minutes)
- **Results** tab
  - Top 3 picks from saved + nearby candidates
  - Veto and re-pick
  - Spin again using the same filters and pool
  - Choose a saved restaurant to log a visit
  - Save nearby places to your list (with dedupe by name)
- **Restaurants** tab
  - Search
  - Add / Edit
  - Swipe to delete
- **History** tab
  - Visits grouped by day
  - Quick thumbs up / thumbs down ratings

## Tech Stack

- **SwiftUI**
- **SwiftData** (iOS 17+ style APIs; project currently targets newer SDKs)
- **MapKit** + **CoreLocation** (no Google APIs)
- No third-party dependencies

## Core Data Model (SwiftData)

- `Restaurant`
  - name, cuisines, price, distance, favorite/new flags
  - last visited, visit count, user rating
- `Visit`
  - restaurant reference by `restaurantId`
  - date
  - rating

## Picker Behavior (Current)

The picker uses weighted random selection (not just max score) and considers:
- cuisine filter
- distance filter
- anti-repeat (exclude saved places visited in the last 7 days)
- recent cuisine penalty (last 3 days)
- novelty bonus
- favorite/rating boosts and penalties

Saved + nearby candidates are merged with dedupe:
- if a nearby place matches a saved restaurant name (case-insensitive), the saved one wins

## Nearby Scan Notes

- Nearby results are **transient** (not saved automatically)
- Nearby scan uses Apple Maps search for `"restaurant"`
- Nearby results are cached in memory for **10 minutes**
- If location is unavailable or permission is not granted, the app shows an inline error
- On Simulator, set a simulated location:
  - `Features` -> `Location` -> choose a location (for example `Apple`)

## Running the App

1. Open `WhereToEat.xcodeproj` in Xcode.
2. Run the `WhereToEat` scheme on an iPhone simulator.
3. Allow location permission when testing Nearby scan.

## Project Structure (Current)

- `WhereToEat/ContentView.swift`
  - Tab shell and most current UI flows
- `WhereToEat/Models/`
  - `Restaurant.swift`
  - `Visit.swift`
  - `CandidateRestaurant.swift`
- `WhereToEat/Services/`
  - `PickerEngine.swift`
  - `NearbySearchService.swift`
  - `NearbyRestaurantService.swift` (nearby cache/scaffold)
- `WhereToEat/AppState.swift`
  - shared UI/session state for nearby scan + cross-tab actions

## Status

This is an in-progress app with a working picker flow, visit logging, and nearby import. UI is intentionally minimal while core behavior is being built out.

