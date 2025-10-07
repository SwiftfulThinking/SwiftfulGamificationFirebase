//
//  ExperiencePointsEvent+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulGamification

extension ExperiencePointsEvent {

    /// Initialize from Firestore document data
    public init(firestoreData: [String: Any]) throws {
        let metadataDict = firestoreData[CodingKeys.metadata.rawValue] as? [String: Any] ?? [:]
        let metadata = try metadataDict.mapValues { value throws -> GamificationDictionaryValue in
            try GamificationDictionaryValue(firestoreValue: value)
        }

        self.init(
            id: firestoreData[CodingKeys.id.rawValue] as? String ?? UUID().uuidString,
            experienceKey: firestoreData[CodingKeys.experienceKey.rawValue] as? String ?? "",
            timestamp: (firestoreData[CodingKeys.timestamp.rawValue] as? Timestamp)?.dateValue() ?? Date(),
            points: firestoreData[CodingKeys.points.rawValue] as? Int ?? 0,
            metadata: metadata
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.id.rawValue: id,
            CodingKeys.experienceKey.rawValue: experienceKey,
            CodingKeys.timestamp.rawValue: Timestamp(date: timestamp),
            CodingKeys.points.rawValue: points
        ]

        // Convert metadata to Firestore-compatible format
        let metadataDict = metadata.mapValues { $0.firestoreValue }
        data[CodingKeys.metadata.rawValue] = metadataDict

        return data
    }
}
