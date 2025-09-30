// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftfulGamificationFirebase",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftfulGamificationFirebase",
            targets: ["SwiftfulGamificationFirebase"]),
    ],
    dependencies: [
        // Here we add the dependency for the SendableDictionary package
        .package(url: "https://github.com/SwiftfulThinking/SwiftfulFirestore.git", "11.0.0"..<"12.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftfulGamificationFirebase",
            dependencies: [
                .product(name: "SwiftfulFirestore", package: "SwiftfulFirestore"),
            ]
        ),
        .testTarget(
            name: "SwiftfulGamificationFirebaseTests",
            dependencies: ["SwiftfulGamificationFirebase"]
        ),
    ]
)
