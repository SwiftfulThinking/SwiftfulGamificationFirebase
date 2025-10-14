# Firebase for SwiftfulGamification ✅

Add Firebase Firestore support to a Swift application through SwiftfulGamification framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulGamification

## Example configuration:

```swift
import SwiftfulGamification
import SwiftfulGamificationFirebase

// Streaks
#if DEBUG
let streakManager = StreakManager(
    services: MockStreakServices(),
    configuration: StreakConfiguration.mockDefault()
)
#else
let streakManager = StreakManager(
    services: ProdStreakServices(),
    configuration: StreakConfiguration(streakKey: "daily")
)
#endif

// Experience Points
#if DEBUG
let xpManager = ExperiencePointsManager(
    services: MockExperiencePointsServices(),
    configuration: ExperiencePointsConfiguration.mockDefault()
)
#else
let xpManager = ExperiencePointsManager(
    services: ProdExperiencePointsServices(),
    configuration: ExperiencePointsConfiguration(experienceKey: "general")
)
#endif

// Progress
#if DEBUG
let progressManager = ProgressManager(
    services: MockProgressServices(),
    configuration: ProgressConfiguration.mockDefault()
)
#else
let progressManager = ProgressManager(
    services: ProdProgressServices(),
    configuration: ProgressConfiguration(progressKey: "general")
)
#endif

// Services Implementation
@MainActor
struct ProdStreakServices: StreakServices {
    let remote: RemoteStreakService
    let local: LocalStreakPersistence

    init() {
        self.remote = FirebaseRemoteStreakService(rootCollectionName: "streaks")
        self.local = FileManagerStreakPersistence()
    }
}

@MainActor
struct ProdExperiencePointsServices: ExperiencePointsServices {
    let remote: RemoteExperiencePointsService
    let local: LocalExperiencePointsPersistence

    init() {
        self.remote = FirebaseRemoteExperiencePointsService(rootCollectionName: "experience")
        self.local = FileManagerExperiencePointsPersistence()
    }
}

@MainActor
struct ProdProgressServices: ProgressServices {
    let remote: RemoteProgressService
    let local: LocalProgressPersistence

    init() {
        self.remote = FirebaseRemoteProgressService(rootCollectionName: "progress")
        self.local = SwiftDataProgressPersistence()
    }
}
```

## Firebase Firestore Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase docs: https://firebase.google.com/docs/firestore

### 1. Create a Firebase project and enable Firestore
* Firebase Console: https://console.firebase.google.com/
* Build -> Firestore Database -> Create database

### 2. Add Firebase to your iOS app
* Follow the Firebase setup guide: https://firebase.google.com/docs/ios/setup
* Add GoogleService-Info.plist to your project

### 3. Configure Firestore Security Rules

Example security rules for user-owned data:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }

    match /streaks/{userId}/{document=**} {
      allow read, write: if isOwner(userId);
    }

    match /experience/{userId}/{document=**} {
      allow read, write: if isOwner(userId);
    }

    match /progress/{userId}/{document=**} {
      allow read, write: if isOwner(userId);
    }
  }
}
```

### 4. Follow remaining steps on parent repo docs
Parent repo: https://github.com/SwiftfulThinking/SwiftfulGamification

</details>
