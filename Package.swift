// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Errors",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Errors",
            targets: [
                "Errors",
            ]
        ),
        .library(
            name: "ErrorsDSL",
            targets: [
                "ErrorsDSL",
            ]
        ),
        .executable(
            name: "t_errors",
            targets: [
                "ErrorsTests",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/DSL.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Testing.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Errors",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
            ]
        ),
        .target(
            name: "ErrorsDSL",
            dependencies: [
                "Errors",
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
            ]
        ),
        .executableTarget(
            name: "ErrorsTests",
            dependencies: [
                "Errors",
                "ErrorsDSL",
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "Testing",
                    package: "Testing"
                ),
            ],
            path: "Testing/ErrorsTests"
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
