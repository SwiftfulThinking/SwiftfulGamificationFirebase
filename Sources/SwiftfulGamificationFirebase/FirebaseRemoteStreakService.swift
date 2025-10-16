//
//  FirebaseRemoteStreakService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteStreakService: RemoteStreakService {

    private let rootCollectionName: String
    private let calculateStreakCloudFunctionName: String?

    private func userStreakCollection(userId: String, streakKey: String) -> CollectionReference {
        Firestore.firestore().collection(rootCollectionName)
            .document(userId)
            .collection(streakKey)
    }

    private func currentStreakDoc(userId: String, streakKey: String) -> DocumentReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("current_streak")
    }

    private func eventsCollection(userId: String, streakKey: String) -> CollectionReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("streak_events")
            .collection("data")
    }

    private func freezesCollection(userId: String, streakKey: String) -> CollectionReference {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .document("streak_freezes")
            .collection("data")
    }

    /// Initialize the Firebase Remote Streak Service
    /// - Parameters:
    ///   - rootCollectionName: The root Firestore collection where all streak data is stored.
    ///     Each user's streak data will be stored under: `{rootCollectionName}/{userId}/{streakKey}/...`
    ///     Example: "swiftful_streaks" → "swiftful_streaks/user123/daily/current_streak"
    ///   - calculateStreakCloudFunctionName: Cloud Function name for server-side streak calculation (e.g., "calculateStreak").
    ///     Required if useServerCalculation = true in StreakConfiguration.
    public init(
        rootCollectionName: String,
        calculateStreakCloudFunctionName: String? = nil
    ) {
        self.rootCollectionName = rootCollectionName
        self.calculateStreakCloudFunctionName = calculateStreakCloudFunctionName
    }

    // MARK: - Current Streak

    public func streamCurrentStreak(userId: String, streakKey: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        userStreakCollection(userId: userId, streakKey: streakKey)
            .streamDocument(id: "current_streak")
    }

    public func updateCurrentStreak(userId: String, streakKey: String, streak: CurrentStreakData) async throws {
        try currentStreakDoc(userId: userId, streakKey: streakKey).setData(from: streak, merge: true)
    }

    public func calculateStreak(userId: String, streakKey: String, eventsRequiredPerDay: Int, leewayHours: Int, freezeBehavior: FreezeBehavior, timezone: String?) async throws {
        precondition(
            calculateStreakCloudFunctionName != nil,
            "calculateStreakCloudFunctionName must be provided in init when useServerCalculation = true"
        )

        guard let cloudFunctionName = calculateStreakCloudFunctionName else {
            throw URLError(.badURL)
        }

        let functions = Functions.functions()

        var parameters: [String: Any] = [
            "userId": userId,
            "streakKey": streakKey,
            "configuration": [
                "streak_id": streakKey,
                "events_required_per_day": eventsRequiredPerDay,
                "use_server_calculation": true,
                "leeway_hours": leewayHours,
                "freeze_behavior": freezeBehavior.rawValue
            ],
            "rootCollectionName": rootCollectionName
        ]

        if let timezone = timezone {
            parameters["timezone"] = timezone
        }

        let _ = try await functions.httpsCallable(cloudFunctionName).call(parameters)
    }

    // MARK: - Events

    public func addEvent(userId: String, streakKey: String, event: StreakEvent) async throws {
        try eventsCollection(userId: userId, streakKey: streakKey).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, streakKey: String) async throws -> [StreakEvent] {
        try await eventsCollection(userId: userId, streakKey: streakKey)
            .order(by: StreakEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, streakKey: String) async throws {
        try await eventsCollection(userId: userId, streakKey: streakKey).deleteAllDocuments()
    }

    // MARK: - Freezes

    public func addStreakFreeze(userId: String, streakKey: String, freeze: StreakFreeze) async throws {
        try freezesCollection(userId: userId, streakKey: streakKey).document(freeze.id).setData(from: freeze, merge: false)
    }

    public func useStreakFreeze(userId: String, streakKey: String, freezeId: String) async throws {
        try await freezesCollection(userId: userId, streakKey: streakKey).updateDocument(id: freezeId, dict: [
            StreakFreeze.CodingKeys.usedDate.rawValue: Timestamp(date: Date())
        ])
    }

    public func getAllStreakFreezes(userId: String, streakKey: String) async throws -> [StreakFreeze] {
        try await freezesCollection(userId: userId, streakKey: streakKey)
            .order(by: StreakFreeze.CodingKeys.earnedDate.rawValue, descending: false)
            .getAllDocuments()
    }
}
