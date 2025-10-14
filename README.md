# Firebase for SwiftfulGamification ✅

Add Firebase Firestore support to a Swift application through SwiftfulGamification framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulGamification

## Example configuration:

```swift
// Streaks
#if DEBUG
let streakManager = StreakManager(
    services: MockStreakServices(),
    configuration: StreakConfiguration.mockDefault(),
    logger: logManager
)
#else
let streakManager = StreakManager(
    services: ProdStreakServices(),
    configuration: StreakConfiguration(
        streakKey: "daily",
        eventsRequiredPerDay: 1,
        useServerCalculation: false,
        leewayHours: 0,
        freezeBehavior: .autoConsumeFreezes
    ),
    logger: logManager
)
#endif

// Experience Points
#if DEBUG
let xpManager = ExperiencePointsManager(
    services: MockExperiencePointsServices(),
    configuration: ExperiencePointsConfiguration.mockDefault(),
    logger: logManager
)
#else
let xpManager = ExperiencePointsManager(
    services: ProdExperiencePointsServices(),
    configuration: ExperiencePointsConfiguration(
        experienceKey: "general",
        useServerCalculation: false
    ),
    logger: logManager
)
#endif

// Progress
#if DEBUG
let progressManager = ProgressManager(
    services: MockProgressServices(),
    configuration: ProgressConfiguration.mockDefault(),
    logger: logManager
)
#else
let progressManager = ProgressManager(
    services: ProdProgressServices(),
    configuration: ProgressConfiguration(
        progressKey: "general"
    ),
    logger: logManager
)
#endif
```

### Services Implementation:

```swift
import SwiftfulGamification
import SwiftfulGamificationFirebase

@MainActor
struct ProdStreakServices: StreakServices {
    let remote: RemoteStreakService
    let local: LocalStreakPersistence

    init() {
        self.remote = FirebaseRemoteStreakService(rootCollectionName: "st_streaks")
        self.local = FileManagerStreakPersistence()
    }
}

@MainActor
struct ProdExperiencePointsServices: ExperiencePointsServices {
    let remote: RemoteExperiencePointsService
    let local: LocalExperiencePointsPersistence

    init() {
        self.remote = FirebaseRemoteExperiencePointsService(rootCollectionName: "st_experience")
        self.local = FileManagerExperiencePointsPersistence()
    }
}

@MainActor
struct ProdProgressServices: ProgressServices {
    let remote: RemoteProgressService
    let local: LocalProgressPersistence

    init() {
        self.remote = FirebaseRemoteProgressService(rootCollectionName: "st_progress")
        self.local = SwiftDataProgressPersistence()
    }
}
```

## Example actions:

### Streaks
```swift
// Login and setup
try await streakManager.logIn(userId: userId)

// Add streak event
try await streakManager.addStreakEvent()
try await streakManager.addStreakEvent(timestamp: Date(), metadata: ["action": "workout"])

// Manage freezes
try await streakManager.addStreakFreeze(id: "freeze_123", expiresAt: Date().addingTimeInterval(86400 * 7))
try await streakManager.useStreakFreezes()

// Access current data
let currentStreak = streakManager.currentStreakData.currentStreak
let isActive = streakManager.currentStreakData.isStreakActive

// Cleanup
streakManager.logOut()
```

### Experience Points
```swift
// Login and setup
try await xpManager.logIn(userId: userId)

// Add XP
try await xpManager.addExperiencePoints(points: 100)
try await xpManager.addExperiencePoints(points: 50, metadata: ["action": "quest_complete"])

// Query events
let allEvents = try await xpManager.getAllExperiencePointsEvents()
let questEvents = try await xpManager.getAllExperiencePointsEvents(forField: "action", equalTo: "quest_complete")

// Access current data
let totalPoints = xpManager.currentExperiencePointsData.pointsAllTime
let todayPoints = xpManager.currentExperiencePointsData.pointsToday

// Cleanup
xpManager.logOut()
```

### Progress
```swift
// Login and setup
try await progressManager.logIn(userId: userId)

// Add progress
try await progressManager.addProgress(id: "level_5", value: 0.75, metadata: ["type": "level"])
try await progressManager.addProgress(id: "achievement_warrior", value: 1.0, metadata: ["category": "combat"])

// Query progress
let progress = progressManager.getProgress(id: "level_5")
let allProgress = progressManager.getAllProgress()
let combatAchievements = progressManager.getProgressItems(forMetadataField: "category", equalTo: "combat")

// Delete progress
try await progressManager.deleteProgress(id: "level_5")

// Cleanup
await progressManager.logOut()
```

## Firebase Firestore Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

### 1. Create a Firebase project
Firebase Console: https://console.firebase.google.com/

### 2. Add Firebase to your iOS app
Follow the Firebase setup guide: https://firebase.google.com/docs/ios/setup

### 3. Enable Firestore Database
* Firebase Console -> Build -> Firestore Database
* Create database in production mode or test mode
* Choose a Cloud Firestore location

### 4. Configure Firestore Security Rules

The Firebase services in this package use the following Firestore structure:
```
{rootCollectionName}/
  └── {userId}/
      ├── {streakKey}/
      │   ├── current_streak          (CurrentStreakData)
      │   ├── streak_events/
      │   │   └── data/               (StreakEvent collection)
      │   └── streak_freezes/
      │       └── data/               (StreakFreeze collection)
      ├── {experienceKey}/
      │   ├── current_xp              (CurrentExperiencePointsData)
      │   └── xp_events/
      │       └── data/               (ExperiencePointsEvent collection)
      └── {progressKey}/
          └── {progressItemId}        (ProgressItem documents)
```

Example security rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated and owns the data
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }

    // Streaks data
    match /st_streaks/{userId}/{streakKey}/{document=**} {
      allow read, write: if isOwner(userId);
    }

    // Experience Points data
    match /st_experience/{userId}/{experienceKey}/{document=**} {
      allow read, write: if isOwner(userId);
    }

    // Progress data
    match /st_progress/{userId}/{progressKey}/{document=**} {
      allow read, write: if isOwner(userId);
    }
  }
}
```

### 5. (Optional) Deploy Cloud Functions for server-side calculations

For server-side streak and XP calculations, deploy Cloud Functions:

```typescript
// Example Cloud Function for streak calculation
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const calculateStreak = functions.https.onCall(async (data, context) => {
  const { userId, streakKey } = data;

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Implement your server-side streak calculation logic here
  // This allows for more complex calculations without client-side processing

  return { success: true };
});
```

Enable server-side calculation in configuration:
```swift
StreakConfiguration(
    streakKey: "daily",
    eventsRequiredPerDay: 1,
    useServerCalculation: true, // Enable server-side calculation
    leewayHours: 0,
    freezeBehavior: .autoConsumeFreezes
)
```

</details>

## Root Collection Names

Configure custom Firestore collection names when initializing services:

```swift
// Default collection names (as shown in examples above):
FirebaseRemoteStreakService(rootCollectionName: "st_streaks")
FirebaseRemoteExperiencePointsService(rootCollectionName: "st_experience")
FirebaseRemoteProgressService(rootCollectionName: "st_progress")

// Custom collection names:
FirebaseRemoteStreakService(rootCollectionName: "my_custom_streaks")
FirebaseRemoteExperiencePointsService(rootCollectionName: "my_custom_xp")
FirebaseRemoteProgressService(rootCollectionName: "my_custom_progress")
```

## Local Persistence Options

The package supports multiple local persistence strategies:

### File Manager (Streaks & XP)
```swift
let local = FileManagerStreakPersistence()
let local = FileManagerExperiencePointsPersistence()
```

### SwiftData (Progress)
```swift
let local = SwiftDataProgressPersistence()
```

### In-Memory (Testing only)
```swift
let local = InMemoryStreakPersistence()
let local = InMemoryExperiencePointsPersistence()
let local = InMemoryProgressPersistence()
```

## Dependencies

This package requires:
- SwiftfulGamification (base package)
- SwiftfulFirestore (Firestore utilities)
- Firebase iOS SDK (FirebaseFirestore, FirebaseAuth)

See `Package.swift` for version requirements.
