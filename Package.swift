// swift-tools-version: 6.3
import PackageDescription

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
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.3.0"),
    ],
    targets: [
        .target(
            name: "AuthenticationHummingbird",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ]
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
            ]
        ),
    ]
)
