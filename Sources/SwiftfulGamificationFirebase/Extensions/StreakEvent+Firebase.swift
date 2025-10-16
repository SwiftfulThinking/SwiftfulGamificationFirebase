//
//  StreakEvent+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulGamification

extension StreakEvent {

    /// Initialize from Firestore document data
    public init(firestoreData: [String: Any]) throws {
        let metadataDict = firestoreData[CodingKeys.metadata.rawValue] as? [String: Any] ?? [:]
        let metadata = try metadataDict.mapValues { value throws -> GamificationDictionaryValue in
            try GamificationDictionaryValue(firestoreValue: value)
        }

        self.init(
            id: firestoreData[CodingKeys.id.rawValue] as? String ?? UUID().uuidString,
            dateCreated: (firestoreData[CodingKeys.dateCreated.rawValue] as? Timestamp)?.dateValue() ?? Date(),
            timezone: firestoreData[CodingKeys.timezone.rawValue] as? String ?? TimeZone.current.identifier,
            isFreeze: firestoreData[CodingKeys.isFreeze.rawValue] as? Bool ?? false,
            freezeId: firestoreData[CodingKeys.freezeId.rawValue] as? String,
            metadata: metadata
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.id.rawValue: id,
            CodingKeys.dateCreated.rawValue: Timestamp(date: dateCreated),
            CodingKeys.timezone.rawValue: timezone,
            CodingKeys.isFreeze.rawValue: isFreeze
        ]

        if let freezeId = freezeId {
            data[CodingKeys.freezeId.rawValue] = freezeId
        }

        // Convert metadata to Firestore-compatible format
        let metadataDict = metadata.mapValues { $0.firestoreValue }
        data[CodingKeys.metadata.rawValue] = metadataDict

        return data
    }
}
