//
//  FirebaseRemoteStreakService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteStreakService: RemoteStreakService {

    private let streakId: String

    private var db: Firestore {
        Firestore.firestore()
    }

    private func currentStreakDoc(userId: String) -> DocumentReference {
        db.collection("swiftful_gamification")
            .document(userId)
            .collection(streakId)
            .document("current_streak")
    }

    private func eventsCollection(userId: String) -> CollectionReference {
        db.collection("swiftful_gamification")
            .document(userId)
            .collection(streakId)
            .document("streak_events")
            .collection("data")
    }

    private func freezesCollection(userId: String) -> CollectionReference {
        db.collection("swiftful_gamification")
            .document(userId)
            .collection(streakId)
            .document("streak_freezes")
            .collection("data")
    }

    public init(streakId: String) {
        self.streakId = streakId
    }

    // MARK: - Current Streak

    public func getCurrentStreak(userId: String) async throws -> CurrentStreakData {
        try await currentStreakDoc(userId: userId).getDocument(as: CurrentStreakData.self)
    }

    public func updateCurrentStreak(userId: String, streak: CurrentStreakData) async throws {
        try currentStreakDoc(userId: userId).setData(from: streak, merge: true)
    }

    public func streamCurrentStreak(userId: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        db.collection("swiftful_gamification")
            .document(userId)
            .collection(streakId)
            .streamDocument(id: "current_streak")
    }

    // MARK: - Events

    public func addEvent(userId: String, event: StreakEvent) async throws {
        try eventsCollection(userId: userId).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String) async throws -> [StreakEvent] {
        try await eventsCollection(userId: userId)
            .order(by: StreakEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String) async throws {
        try await eventsCollection(userId: userId).deleteAllDocuments()
    }

    // MARK: - Freezes

    public func addStreakFreeze(userId: String, freeze: StreakFreeze) async throws {
        try freezesCollection(userId: userId).document(freeze.id).setData(from: freeze, merge: false)
    }

    public func useStreakFreeze(userId: String, freezeId: String) async throws {
        try await freezesCollection(userId: userId).updateDocument(id: freezeId, dict: [
            StreakFreeze.CodingKeys.usedDate.rawValue: Timestamp(date: Date())
        ])
    }

    public func getAllStreakFreezes(userId: String) async throws -> [StreakFreeze] {
        try await freezesCollection(userId: userId)
            .order(by: StreakFreeze.CodingKeys.earnedDate.rawValue, descending: false)
            .getAllDocuments()
    }

    // MARK: - Server Calculation

    public func calculateStreak(userId: String) async throws {
        // Trigger Cloud Function for server-side calculation
        // Implementation depends on your Cloud Function setup
        // For now, this is a placeholder that writes a trigger flag

//         let functions = Functions.functions()
//         let result = try await functions.httpsCallable("calculateStreak").call([
//             "userId": userId,
//             "streakId": streakId
//         ])
    }
}
