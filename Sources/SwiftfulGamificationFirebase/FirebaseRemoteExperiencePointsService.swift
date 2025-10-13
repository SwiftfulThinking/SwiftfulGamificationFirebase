//
//  FirebaseRemoteExperiencePointsService.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulGamification

@MainActor
public struct FirebaseRemoteExperiencePointsService: RemoteExperiencePointsService {

    private let rootCollectionName: String

    private func userExperienceCollection(userId: String, experienceKey: String) -> CollectionReference {
        Firestore.firestore().collection(rootCollectionName)
            .document(userId)
            .collection(experienceKey)
    }

    private func currentExperiencePointsDoc(userId: String, experienceKey: String) -> DocumentReference {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .document("current_xp")
    }

    private func eventsCollection(userId: String, experienceKey: String) -> CollectionReference {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .document("xp_events")
            .collection("data")
    }

    public init(rootCollectionName: String = "swiftful_experience") {
        self.rootCollectionName = rootCollectionName
    }

    // MARK: - Current Experience Points

    public func streamCurrentExperiencePoints(userId: String, experienceKey: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error> {
        userExperienceCollection(userId: userId, experienceKey: experienceKey)
            .streamDocument(id: "current_xp")
    }

    public func updateCurrentExperiencePoints(userId: String, experienceKey: String, data: CurrentExperiencePointsData) async throws {
        try currentExperiencePointsDoc(userId: userId, experienceKey: experienceKey).setData(from: data, merge: true)
    }

    public func calculateExperiencePoints(userId: String, experienceKey: String) async throws {
        // Trigger Cloud Function for server-side calculation
        // Implementation depends on your Cloud Function setup
        // For now, this is a placeholder that writes a trigger flag

//         let functions = Functions.functions()
//         let result = try await functions.httpsCallable("calculateExperiencePoints").call([
//             "userId": userId,
//             "experienceKey": experienceKey
//         ])
    }

    // MARK: - Events

    public func addEvent(userId: String, experienceKey: String, event: ExperiencePointsEvent) async throws {
        try eventsCollection(userId: userId, experienceKey: experienceKey).document(event.id).setData(from: event, merge: false)
    }

    public func getAllEvents(userId: String, experienceKey: String) async throws -> [ExperiencePointsEvent] {
        try await eventsCollection(userId: userId, experienceKey: experienceKey)
            .order(by: ExperiencePointsEvent.CodingKeys.timestamp.rawValue, descending: false)
            .getAllDocuments()
    }

    public func deleteAllEvents(userId: String, experienceKey: String) async throws {
        try await eventsCollection(userId: userId, experienceKey: experienceKey).deleteAllDocuments()
    }
}
