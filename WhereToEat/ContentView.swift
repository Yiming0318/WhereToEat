//
//  ContentView.swift
//  WhereToEat
//
//  Created by YIMING GE on 2/23/26.
//

import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

private enum AppTab: Hashable {
    case pick
    case results
    case restaurants
    case history
}

@MainActor
final class PickerSessionState: ObservableObject {
    struct RequestContext {
        var selectedCuisines: Set<String>
        var maxDistanceMiles: Double?
        var noveltyMode: PickerEngine.NoveltyMode
        var pool: [CandidateRestaurant]
    }

    @Published var pickedCandidates: [CandidateRestaurant] = []
    @Published var vetoedCandidateIds: Set<String> = []

    var lastRequestContext: RequestContext?

    func setPicks(_ restaurants: [Restaurant]) {
        pickedCandidates = restaurants.map(CandidateRestaurant.fromSaved)
    }

    func setCandidatePicks(_ candidates: [CandidateRestaurant]) {
        pickedCandidates = candidates
    }

    func startCandidateSession(
        context: RequestContext,
        picks: [CandidateRestaurant]
    ) {
        lastRequestContext = context
        vetoedCandidateIds = []
        pickedCandidates = picks
    }

    func veto(_ candidate: CandidateRestaurant) {
        vetoedCandidateIds.insert(candidate.id)
    }

    func replaceCandidateInSession(oldCandidateId: String, with savedCandidate: CandidateRestaurant) {
        if let index = pickedCandidates.firstIndex(where: { $0.id == oldCandidateId }) {
            pickedCandidates[index] = savedCandidate
        }

        if var context = lastRequestContext {
            if let poolIndex = context.pool.firstIndex(where: { $0.id == oldCandidateId }) {
                context.pool[poolIndex] = savedCandidate
            } else {
                context.pool.append(savedCandidate)
            }
            lastRequestContext = context
        }

        vetoedCandidateIds.remove(oldCandidateId)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var pickerState = PickerSessionState()
    @State private var selectedTab: AppTab = .pick

    var body: some View {
        TabView(selection: $selectedTab) {
            PickTabView(pickerState: pickerState, selectedTab: $selectedTab)
                .tag(AppTab.pick)
                .tabItem { Label("Pick", systemImage: "dice") }

            ResultsTabView(pickerState: pickerState, selectedTab: $selectedTab)
                .tag(AppTab.results)
                .tabItem { Label("Results", systemImage: "sparkles.rectangle.stack") }

            RestaurantsTabView()
                .tag(AppTab.restaurants)
                .tabItem { Label("Restaurants", systemImage: "fork.knife") }

            HistoryTabView()
                .tag(AppTab.history)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .task {
            seedRestaurantsIfNeeded()
        }
    }

    private func seedRestaurantsIfNeeded() {
        do {
            let count = try modelContext.fetchCount(FetchDescriptor<Restaurant>())
            guard count == 0 else { return }

            for restaurant in Self.seedRestaurants {
                modelContext.insert(restaurant)
            }
            try modelContext.save()
        } catch {
            assertionFailure("Failed to seed restaurants: \(error)")
        }
    }

    private static let seedRestaurants: [Restaurant] = [
        Restaurant(name: "Golden Wok", cuisines: ["Chinese"], priceLevel: 2, distanceMiles: 1.2, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 10), visitCount: 6, userRating: 1),
        Restaurant(name: "Seoul Table", cuisines: ["Korean"], priceLevel: 2, distanceMiles: 2.5, isFavorite: false, isNew: true, visitCount: 0),
        Restaurant(name: "Sakura Bento", cuisines: ["Japanese"], priceLevel: 2, distanceMiles: 0.9, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 3), visitCount: 12, userRating: 1),
        Restaurant(name: "Bangkok Street", cuisines: ["Thai"], priceLevel: 2, distanceMiles: 3.1, isFavorite: false, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 30), visitCount: 2, userRating: 0),
        Restaurant(name: "Spice Route", cuisines: ["Indian"], priceLevel: 3, distanceMiles: 4.0, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 21), visitCount: 5, userRating: 1),
        Restaurant(name: "Patty Lab", cuisines: ["Burgers"], priceLevel: 2, distanceMiles: 1.8, isFavorite: false, isNew: true, visitCount: 0),
        Restaurant(name: "Brick Oven Co.", cuisines: ["Pizza"], priceLevel: 2, distanceMiles: 2.2, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 14), visitCount: 8, userRating: 1),
        Restaurant(name: "Casa Verde", cuisines: ["Mexican"], priceLevel: 2, distanceMiles: 2.9, isFavorite: false, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 60), visitCount: 3, userRating: 0),
        Restaurant(name: "Harvest Bowl", cuisines: ["Healthy"], priceLevel: 3, distanceMiles: 1.1, isFavorite: false, isNew: true, visitCount: 0),
        Restaurant(name: "Pho Corner", cuisines: ["Vietnamese"], priceLevel: 2, distanceMiles: 3.8, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 7), visitCount: 7, userRating: 1),
        Restaurant(name: "Mediterranean Grill", cuisines: ["Mediterranean"], priceLevel: 3, distanceMiles: 4.6, isFavorite: false, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 45), visitCount: 2, userRating: 0),
        Restaurant(name: "Taco Garage", cuisines: ["Mexican", "Street Food"], priceLevel: 1, distanceMiles: 2.0, isFavorite: false, isNew: true, visitCount: 0),
        Restaurant(name: "Ramen Engine", cuisines: ["Japanese", "Ramen"], priceLevel: 2, distanceMiles: 2.7, isFavorite: true, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 5), visitCount: 9, userRating: 1),
        Restaurant(name: "Green Leaf Cafe", cuisines: ["Healthy", "Cafe"], priceLevel: 2, distanceMiles: 0.6, isFavorite: false, isNew: false, lastVisited: .now.addingTimeInterval(-86400 * 18), visitCount: 4, userRating: 0),
        Restaurant(name: "Smokehouse Yard", cuisines: ["BBQ"], priceLevel: 3, distanceMiles: 5.4, isFavorite: false, isNew: true, visitCount: 0),
    ]
}

private struct PickTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    @ObservedObject var pickerState: PickerSessionState
    @Binding var selectedTab: AppTab

    @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]
    @Query(sort: \Visit.date, order: .reverse) private var visits: [Visit]

    @State private var selectedCuisines: Set<String> = []
    @State private var anyDistance = true
    @State private var maxDistanceMiles = 5.0
    @State private var noveltySelection: PickNoveltyOption = .balanced
    @State private var openNowOnly = false
    @State private var isScanningNearby = false
    @State private var nearbyErrorMessage: String?
    @State private var canOpenSettingsForNearbyError = false

    private var availableCuisines: [String] {
        Array(Set(restaurants.flatMap(\.cuisines)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        runPicker()
                    } label: {
                        Label("Pick for us", systemImage: "dice.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(restaurants.isEmpty)
                }

                Section("Cuisines") {
                    if availableCuisines.isEmpty {
                        Text("No cuisines available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                            ForEach(availableCuisines, id: \.self) { cuisine in
                                Button {
                                    toggleCuisine(cuisine)
                                } label: {
                                    Text(cuisine)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCuisines.contains(cuisine) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedCuisines.contains(cuisine) ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Distance") {
                    Toggle("Any distance", isOn: $anyDistance)

                    HStack {
                        Text("Max")
                        Slider(value: $maxDistanceMiles, in: 1...10, step: 1)
                            .disabled(anyDistance)
                        Text("\(Int(maxDistanceMiles)) mi")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(anyDistance ? .secondary : .primary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .opacity(anyDistance ? 0.45 : 1)
                }

                Section("Novelty") {
                    Picker("Novelty", selection: $noveltySelection) {
                        ForEach(PickNoveltyOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Nearby") {
                    Toggle("Include Nearby", isOn: $appState.includeNearby)

                    if appState.includeNearby {
                        Toggle("Only Nearby", isOn: $appState.onlyNearby)

                        Picker("Radius", selection: $appState.nearbyRadiusMiles) {
                            Text("0.5 mi").tag(0.5)
                            Text("1 mi").tag(1.0)
                            Text("2 mi").tag(2.0)
                            Text("5 mi").tag(5.0)
                        }
                        .pickerStyle(.segmented)

                        Button {
                            scanNearby()
                        } label: {
                            HStack {
                                if isScanningNearby {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(scanButtonTitle)
                                Spacer()
                            }
                        }
                        .disabled(isScanningNearby || appState.nearbyIsFresh)

                        if let nearbyErrorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(nearbyErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)

                                if canOpenSettingsForNearbyError {
                                    Button("Open Settings") {
                                        openAppSettings()
                                    }
                                    .font(.footnote.weight(.semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if appState.nearbyLastUpdated != nil {
                            Text(nearbyStatusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Open now only", isOn: $openNowOnly)
                } header: {
                    Text("Filters")
                } footer: {
                    Text("Open-now filter is not implemented yet.")
                }
            }
            .navigationTitle("Pick")
        }
    }

    private func toggleCuisine(_ cuisine: String) {
        if selectedCuisines.contains(cuisine) {
            selectedCuisines.remove(cuisine)
        } else {
            selectedCuisines.insert(cuisine)
        }
    }

    private func runPicker() {
        let engine = PickerEngine()
        let pool = engine.buildCandidatePool(
            saved: restaurants,
            nearby: appState.nearbyCandidates,
            includeNearby: appState.includeNearby,
            onlyNearby: appState.onlyNearby
        )

        let picks = engine.top3Picks(
            selectedCuisines: selectedCuisines,
            maxDistanceMiles: anyDistance ? nil : maxDistanceMiles,
            noveltyMode: noveltySelection.engineMode,
            vetoedRestaurantIds: [],
            visits: visits,
            candidates: pool
        )

        pickerState.startCandidateSession(
            context: .init(
                selectedCuisines: selectedCuisines,
                maxDistanceMiles: anyDistance ? nil : maxDistanceMiles,
                noveltyMode: noveltySelection.engineMode,
                pool: pool
            ),
            picks: picks
        )
        selectedTab = .results
    }

    private var scanButtonTitle: String {
        if isScanningNearby { return "Scanning..." }
        if appState.nearbyIsFresh { return "Fresh" }
        return "Scan Now"
    }

    private var nearbyStatusText: String {
        var base = "Nearby: \(appState.nearbyCandidates.count) loaded"
        if appState.nearbyIsFresh {
            base += " (cached)"
        }
        return base
    }

    private func scanNearby() {
        nearbyErrorMessage = nil
        canOpenSettingsForNearbyError = false
        isScanningNearby = true

        Task {
            do {
                let results = try await NearbySearchService().fetchNearbyRestaurants(
                    radiusMiles: appState.nearbyRadiusMiles
                )
                appState.nearbyCandidates = results
                appState.nearbyLastUpdated = .now
            } catch let error as NearbySearchError {
                nearbyErrorMessage = error.localizedDescription
                canOpenSettingsForNearbyError = (error == .permissionDenied || error == .locationServicesDisabled)
            } catch {
                nearbyErrorMessage = error.localizedDescription
                canOpenSettingsForNearbyError = false
            }

            isScanningNearby = false
        }
    }

    private func openAppSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
#endif
    }
}

private enum PickNoveltyOption: String, CaseIterable, Identifiable {
    case safe
    case balanced
    case adventure

    var id: Self { self }

    var title: String {
        switch self {
        case .safe: return "Safe"
        case .balanced: return "Balanced"
        case .adventure: return "Adventure"
        }
    }

    var engineMode: PickerEngine.NoveltyMode {
        switch self {
        case .safe: return .safe
        case .balanced: return .balanced
        case .adventure: return .adventure
        }
    }
}

private struct ResultsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @ObservedObject var pickerState: PickerSessionState
    @Binding var selectedTab: AppTab

    @Query private var restaurants: [Restaurant]
    @Query(sort: \Visit.date, order: .reverse) private var visits: [Visit]

    @State private var nearbySavePromptCandidate: CandidateRestaurant?
    @State private var actionErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if !pickerState.pickedCandidates.isEmpty {
                    Section {
                        Button {
                            spinAgain()
                        } label: {
                            Label("Spin again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pickerState.lastRequestContext == nil)
                    }
                }

                ForEach(Array(pickerState.pickedCandidates.enumerated()), id: \.element.id) { index, candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("#\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        CandidateResultRowView(
                            candidate: candidate,
                            onVeto: { vetoAndRepick(candidate) },
                            onChoose: { choose(candidate) }
                        )
                    }
                }
            }
            .navigationTitle("Results")
            .alert("Nearby Place", isPresented: nearbySavePromptPresented) {
                Button("Save") {
                    savePromptCandidateToMyList()
                }
                Button("Cancel", role: .cancel) {
                    nearbySavePromptCandidate = nil
                }
            } message: {
                Text("This is a nearby place not saved yet. Save it to My List first?")
            }
            .alert("Action Error", isPresented: actionErrorPresented, actions: {
                Button("OK") {
                    actionErrorMessage = nil
                }
            }, message: {
                Text(actionErrorMessage ?? "Something went wrong.")
            })
            .overlay {
                if pickerState.pickedCandidates.isEmpty {
                    ContentUnavailableView("No Picks Yet", systemImage: "sparkles.rectangle.stack")
                }
            }
        }
    }

    private var restaurantsById: [UUID: Restaurant] {
        Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })
    }

    private var nearbySavePromptPresented: Binding<Bool> {
        Binding(
            get: { nearbySavePromptCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    nearbySavePromptCandidate = nil
                }
            }
        )
    }

    private var actionErrorPresented: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    actionErrorMessage = nil
                }
            }
        )
    }

    private func spinAgain() {
        guard let context = pickerState.lastRequestContext else { return }

        let filteredPool = context.pool.filter { !pickerState.vetoedCandidateIds.contains($0.id) }
        let picks = PickerEngine().top3Picks(
            selectedCuisines: context.selectedCuisines,
            maxDistanceMiles: context.maxDistanceMiles,
            noveltyMode: context.noveltyMode,
            vetoedRestaurantIds: [],
            visits: visits,
            candidates: filteredPool
        )
        pickerState.setCandidatePicks(picks)
    }

    private func vetoAndRepick(_ candidate: CandidateRestaurant) {
        pickerState.veto(candidate)
        spinAgain()
    }

    private func choose(_ candidate: CandidateRestaurant) {
        switch candidate.source {
        case .nearby:
            nearbySavePromptCandidate = candidate
        case .saved:
            chooseSaved(candidate)
        }
    }

    private func chooseSaved(_ candidate: CandidateRestaurant) {
        guard let savedId = candidate.savedRestaurantId,
              let restaurant = restaurantsById[savedId] else {
            actionErrorMessage = "Saved restaurant could not be found."
            return
        }

        let now = Date()
        let visit = Visit(restaurantId: savedId, date: now, rating: nil)
        modelContext.insert(visit)

        restaurant.lastVisited = now
        restaurant.visitCount += 1
        restaurant.isNew = false

        do {
            try modelContext.save()
            selectedTab = .history
        } catch {
            actionErrorMessage = "Failed to save visit: \(error.localizedDescription)"
        }
    }

    private func savePromptCandidateToMyList() {
        guard let candidate = nearbySavePromptCandidate else { return }
        saveNearbyCandidateToMyList(candidate)
    }

    private func saveNearbyCandidateToMyList(_ candidate: CandidateRestaurant) {
        let normalizedCandidateName = normalizedName(candidate.name)

        if let existing = restaurants.first(where: { normalizedName($0.name) == normalizedCandidateName }) {
            nearbySavePromptCandidate = nil
            appState.requestedRestaurantEditorId = existing.id
            selectedTab = .restaurants
            return
        }

        let newRestaurant = Restaurant(
            name: candidate.name,
            cuisines: [],
            priceLevel: 2,
            distanceMiles: candidate.distanceMiles,
            isFavorite: false,
            isNew: true,
            lastVisited: nil,
            visitCount: 0,
            userRating: nil
        )
        modelContext.insert(newRestaurant)

        do {
            try modelContext.save()

            let savedCandidate = CandidateRestaurant.fromSaved(newRestaurant)
            pickerState.replaceCandidateInSession(oldCandidateId: candidate.id, with: savedCandidate)
            appState.nearbyCandidates.removeAll { $0.id == candidate.id }
            nearbySavePromptCandidate = nil
        } catch {
            actionErrorMessage = "Failed to save restaurant: \(error.localizedDescription)"
        }
    }

    private func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct CandidateResultRowView: View {
    let candidate: CandidateRestaurant
    let onVeto: () -> Void
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(candidate.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if let priceLevel = candidate.priceLevel {
                    Text(String(repeating: "$", count: priceLevel))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !candidate.cuisines.isEmpty {
                Text(candidate.cuisines.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                BadgeChip(title: candidate.source == .saved ? "Saved" : "Nearby", tint: candidate.source == .saved ? .blue : .mint)
                if candidate.isFavorite {
                    BadgeChip(title: "Favorite", tint: .yellow)
                }
                if candidate.isNew {
                    BadgeChip(title: "New", tint: .green)
                }
                if let distanceMiles = candidate.distanceMiles {
                    Text(String(format: "%.1f mi", distanceMiles))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onVeto()
                } label: {
                    Label("Veto", systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                Button {
                    onChoose()
                } label: {
                    Label("Choose", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RestaurantsTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]

    @State private var searchText = ""
    @State private var editorTarget: RestaurantEditorTarget?

    private var filteredRestaurants: [Restaurant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return restaurants }

        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRestaurants) { restaurant in
                    Button {
                        editorTarget = .edit(restaurant)
                    } label: {
                        RestaurantRowView(restaurant: restaurant)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteFilteredRestaurants)
            }
            .overlay {
                if restaurants.isEmpty {
                    ContentUnavailableView("No Restaurants", systemImage: "fork.knife")
                } else if filteredRestaurants.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Restaurants")
            .onAppear {
                openRequestedRestaurantIfNeeded()
            }
            .onChange(of: appState.requestedRestaurantEditorId) { _, _ in
                openRequestedRestaurantIfNeeded()
            }
            .searchable(text: $searchText, prompt: "Search restaurants")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = .add
                    } label: {
                        Label("Add Restaurant", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(restaurants.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(item: $editorTarget) { target in
                RestaurantEditorView(restaurant: target.restaurant)
            }
        }
    }

    private func deleteFilteredRestaurants(offsets: IndexSet) {
        let targets = offsets.map { filteredRestaurants[$0] }
        for restaurant in targets {
            modelContext.delete(restaurant)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to delete restaurant: \(error)")
        }
    }

    private func openRequestedRestaurantIfNeeded() {
        guard let requestedId = appState.requestedRestaurantEditorId else { return }
        guard let restaurant = restaurants.first(where: { $0.id == requestedId }) else { return }
        editorTarget = .edit(restaurant)
        appState.requestedRestaurantEditorId = nil
    }
}

private struct RestaurantRowView: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(restaurant.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(repeating: "$", count: restaurant.priceLevel))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(restaurant.cuisines.joined(separator: " • "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if restaurant.isFavorite {
                    BadgeChip(title: "Favorite", tint: .yellow)
                }
                if restaurant.isNew {
                    BadgeChip(title: "New", tint: .green)
                }
                if let distanceMiles = restaurant.distanceMiles {
                    Text(String(format: "%.1f mi", distanceMiles))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BadgeChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct RestaurantEditorTarget: Identifiable {
    let id = UUID()
    let restaurant: Restaurant?

    static let add = RestaurantEditorTarget(restaurant: nil)

    static func edit(_ restaurant: Restaurant) -> RestaurantEditorTarget {
        RestaurantEditorTarget(restaurant: restaurant)
    }
}

private struct RestaurantEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let restaurant: Restaurant?

    @State private var name: String
    @State private var cuisinesText: String
    @State private var priceLevel: Int
    @State private var distanceText: String
    @State private var isFavorite: Bool
    @State private var isNew: Bool

    init(restaurant: Restaurant?) {
        self.restaurant = restaurant
        _name = State(initialValue: restaurant?.name ?? "")
        _cuisinesText = State(initialValue: restaurant?.cuisines.joined(separator: ", ") ?? "")
        _priceLevel = State(initialValue: restaurant?.priceLevel ?? 2)
        if let distance = restaurant?.distanceMiles {
            _distanceText = State(initialValue: String(format: "%.1f", distance))
        } else {
            _distanceText = State(initialValue: "")
        }
        _isFavorite = State(initialValue: restaurant?.isFavorite ?? false)
        _isNew = State(initialValue: restaurant?.isNew ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Cuisines (comma-separated)", text: $cuisinesText)
                    Stepper("Price: \(String(repeating: "$", count: priceLevel))", value: $priceLevel, in: 1...4)
                    TextField("Distance (miles)", text: $distanceText)
                        .keyboardType(.decimalPad)
                }

                Section("Flags") {
                    Toggle("Favorite", isOn: $isFavorite)
                    Toggle("New", isOn: $isNew)
                }
            }
            .navigationTitle(restaurant == nil ? "Add Restaurant" : "Edit Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cuisines = cuisinesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let distanceMiles = Double(distanceText.trimmingCharacters(in: .whitespacesAndNewlines))

        let target = restaurant ?? Restaurant()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.cuisines = cuisines
        target.priceLevel = min(max(priceLevel, 1), 4)
        target.distanceMiles = distanceMiles
        target.isFavorite = isFavorite
        target.isNew = isNew

        if restaurant == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save restaurant: \(error)")
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage)
                .navigationTitle(title)
        }
    }
}

private struct HistoryTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Visit.date, order: .reverse) private var visits: [Visit]
    @Query private var restaurants: [Restaurant]

    private var restaurantsById: [UUID: Restaurant] {
        Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })
    }

    private var groupedDays: [Date] {
        let starts = Set(visits.map { Calendar.current.startOfDay(for: $0.date) })
        return starts.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedDays, id: \.self) { day in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(visitsForDay(day)) { visit in
                            HistoryVisitRowView(
                                visit: visit,
                                restaurantName: restaurantsById[visit.restaurantId]?.name ?? "Unknown Restaurant",
                                onRate: { rating in
                                    setRating(rating, for: visit)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("History")
            .overlay {
                if visits.isEmpty {
                    ContentUnavailableView("No Visits Yet", systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    private func visitsForDay(_ day: Date) -> [Visit] {
        visits.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private func setRating(_ rating: Int, for visit: Visit) {
        visit.rating = rating
        syncRestaurantUserRating(for: visit.restaurantId)

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to update visit rating: \(error)")
        }
    }

    private func syncRestaurantUserRating(for restaurantId: UUID) {
        guard let restaurant = restaurantsById[restaurantId] else { return }

        let mostRecentRatedVisit = visits.first { candidate in
            candidate.restaurantId == restaurantId && candidate.rating != nil
        }
        restaurant.userRating = mostRecentRatedVisit?.rating
    }
}

private struct HistoryVisitRowView: View {
    let visit: Visit
    let restaurantName: String
    let onRate: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(restaurantName)
                    .font(.headline)
                Spacer()
                Text(ratingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(visit.date.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    onRate(1)
                } label: {
                    Label("Like", systemImage: visit.rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .tint(.green)

                Button {
                    onRate(-1)
                } label: {
                    Label("Dislike", systemImage: visit.rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
                .tint(.red)
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 4)
    }

    private var ratingText: String {
        switch visit.rating {
        case 1: return "👍"
        case -1: return "👎"
        case 0: return "😐"
        default: return "Unrated"
        }
    }
}
