// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ErrorsTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
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
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "ErrorsTests",
            dependencies: [
                .product(name: "Errors", package: "Errors"),
                .product(name: "ErrorsDSL", package: "Errors"),
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
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
