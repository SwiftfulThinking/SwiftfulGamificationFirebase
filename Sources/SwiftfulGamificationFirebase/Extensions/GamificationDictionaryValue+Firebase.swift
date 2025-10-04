//
//  GamificationDictionaryValue+Firebase.swift
//  SwiftfulGamificationFirebase
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import SwiftfulGamification

extension GamificationDictionaryValue {

    /// Initialize from Firestore value
    public init(firestoreValue: Any) throws {
        if let stringValue = firestoreValue as? String {
            self = .string(stringValue)
        } else if let boolValue = firestoreValue as? Bool {
            self = .bool(boolValue)
        } else if let intValue = firestoreValue as? Int {
            self = .int(intValue)
        } else if let doubleValue = firestoreValue as? Double {
            self = .double(doubleValue)
        } else if let floatValue = firestoreValue as? Float {
            self = .float(floatValue)
        } else if let cgFloatValue = firestoreValue as? CGFloat {
            self = .cgFloat(cgFloatValue)
        } else {
            throw GamificationDictionaryValueError.unsupportedType
        }
    }

    /// Convert to Firestore-compatible value
    public var firestoreValue: Any {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .float(let value):
            return value
        case .cgFloat(let value):
            return value
        }
    }

    enum GamificationDictionaryValueError: Error {
        case unsupportedType
    }
}
