# Firebase for SwiftfulGamification ✅

Add Firebase Firestore support to a Swift application through SwiftfulGamification framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulGamification

## Example configuration:

```swift
// Streaks
#if DEBUG
let streakManager = StreakManager(services: MockStreakServices(), configuration: StreakConfiguration.mockDefault())
#else
let streakManager = StreakManager(services: FirebaseStreakServices(), configuration: StreakConfiguration(streakKey: "daily"))
#endif

// Experience Points
#if DEBUG
let xpManager = ExperiencePointsManager(services: MockExperiencePointsServices(), configuration: ExperiencePointsConfiguration.mockDefault())
#else
let xpManager = ExperiencePointsManager(services: FirebaseExperiencePointsServices(), configuration: ExperiencePointsConfiguration(experienceKey: "general"))
#endif

// Progress
#if DEBUG
let progressManager = ProgressManager(services: MockProgressServices(), configuration: ProgressConfiguration.mockDefault())
#else
let progressManager = ProgressManager(services: FirebaseProgressServices(), configuration: ProgressConfiguration(progressKey: "general"))
#endif
```

## Example actions:

```swift
// Streaks
try await streakManager.logIn(userId: userId)
try await streakManager.addStreakEvent()
try await streakManager.addStreakFreeze(id: "freeze_id", expiresAt: Date())
streakManager.currentStreakData.currentStreak
streakManager.logOut()

// Experience Points
try await xpManager.logIn(userId: userId)
try await xpManager.addExperiencePoints(points: 100)
xpManager.currentExperiencePointsData.pointsAllTime
xpManager.logOut()

// Progress
try await progressManager.logIn(userId: userId)
try await progressManager.addProgress(id: "item_id", value: 0.5)
progressManager.getProgress(id: "item_id")
await progressManager.logOut()
```

## Server Calculations (Optional)

<details>
<summary> Details (Click to expand) </summary>
<br>

The `ServerCalculations/` folder contains Firebase Cloud Functions for server-side streak and XP calculations.

### Deploy Cloud Functions

```bash
# Copy functions to your Firebase project
cp -r ServerCalculations/calculateStreak.ts your-firebase-project/functions/src/
cp -r ServerCalculations/calculateExperiencePoints.ts your-firebase-project/functions/src/

# Deploy to Firebase
cd your-firebase-project
firebase deploy --only functions
```

### Enable Server Calculation

```swift
// Streaks with server calculation
let streakService = FirebaseRemoteStreakService(
    rootCollectionName: "swiftful_streaks",
    calculateStreakCloudFunctionName: "calculateStreak"  // Add function name
)

let streakManager = StreakManager(
    services: FirebaseStreakServices(remote: streakService, local: FileManagerStreakPersistence()),
    configuration: StreakConfiguration(
        streakKey: "daily",
        eventsRequiredPerDay: 1,
        useServerCalculation: true,  // Enable server calculation
        leewayHours: 4,
        freezeBehavior: .autoConsumeFreezes
    )
)

// Experience Points with server calculation
let xpService = FirebaseRemoteExperiencePointsService(
    rootCollectionName: "swiftful_experience_points",
    calculateExperiencePointsCloudFunctionName: "calculateExperiencePoints"
)

let xpManager = ExperiencePointsManager(
    services: FirebaseExperiencePointsServices(remote: xpService, local: FileManagerExperiencePointsPersistence()),
    configuration: ExperiencePointsConfiguration(
        experienceKey: "general",
        useServerCalculation: true  // Enable server calculation
    )
)
```

**Note**: Server calculation is optional. By default, calculations run client-side for offline support and faster updates.

</details>

## Firebase Firestore Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase docs: https://firebase.google.com/docs/firestore

### 1. Enable Firestore in Firebase console
* Firebase Console -> Build -> Firestore Database

### 2. Follow remaining steps on parent repo docs
Parent repo: https://github.com/SwiftfulThinking/SwiftfulGamification

</details>
