//
//  StreakFreeze+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import FirebaseFirestore
import SwiftfulGamification

extension StreakFreeze {

    /// Initialize from Firestore document data
    public init(firestoreData: [String: Any]) throws {
        self.init(
            id: firestoreData[CodingKeys.id.rawValue] as? String ?? UUID().uuidString,
            streakKey: firestoreData[CodingKeys.streakKey.rawValue] as? String ?? "",
            earnedDate: (firestoreData[CodingKeys.earnedDate.rawValue] as? Timestamp)?.dateValue(),
            usedDate: (firestoreData[CodingKeys.usedDate.rawValue] as? Timestamp)?.dateValue(),
            expiresAt: (firestoreData[CodingKeys.expiresAt.rawValue] as? Timestamp)?.dateValue()
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.id.rawValue: id,
            CodingKeys.streakKey.rawValue: streakKey
        ]

        if let earnedDate = earnedDate {
            data[CodingKeys.earnedDate.rawValue] = Timestamp(date: earnedDate)
        }
        if let usedDate = usedDate {
            data[CodingKeys.usedDate.rawValue] = Timestamp(date: usedDate)
        }
        if let expiresAt = expiresAt {
            data[CodingKeys.expiresAt.rawValue] = Timestamp(date: expiresAt)
        }

        return data
    }
}
