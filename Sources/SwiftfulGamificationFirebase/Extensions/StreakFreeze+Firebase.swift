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
            dateEarned: (firestoreData[CodingKeys.dateEarned.rawValue] as? Timestamp)?.dateValue(),
            dateUsed: (firestoreData[CodingKeys.dateUsed.rawValue] as? Timestamp)?.dateValue(),
            dateExpires: (firestoreData[CodingKeys.dateExpires.rawValue] as? Timestamp)?.dateValue()
        )
    }

    /// Convert to Firestore document data
    public var firestoreData: [String: Any] {
        var data: [String: Any] = [
            CodingKeys.id.rawValue: id
        ]

        if let dateEarned = dateEarned {
            data[CodingKeys.dateEarned.rawValue] = Timestamp(date: dateEarned)
        }
        if let dateUsed = dateUsed {
            data[CodingKeys.dateUsed.rawValue] = Timestamp(date: dateUsed)
        }
        if let dateExpires = dateExpires {
            data[CodingKeys.dateExpires.rawValue] = Timestamp(date: dateExpires)
        }

        return data
    }
}
