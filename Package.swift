// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("ExistentialAny"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    .enableUpcomingFeature("InternalImportsByDefault"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "swift-authentication-hummingbird",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AuthenticationHummingbird",
            targets: ["AuthenticationHummingbird"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.27.0", traits: []),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "AuthenticationHummingbird",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AuthenticationHummingbirdTests",
            dependencies: [
                .target(name: "AuthenticationHummingbird"),
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
