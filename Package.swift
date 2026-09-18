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
        // .executable(
        //     name: "errtest",
        //     targets: [
        //         "ErrorsTestFlows",
        //     ]
        // ),
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
        // .package(
        //     url: "https://github.com/leviouwendijk/TestFlows.git",
        //     branch: "master"
        // ),
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
        // .executableTarget(
        //     name: "ErrorsTestFlows",
        //     dependencies: [
        //         "Errors",
        //         "ErrorsDSL",
        //         .product(
        //             name: "DSL",
        //             package: "DSL"
        //         ),
        //         .product(
        //             name: "Primitives",
        //             package: "Primitives"
        //         ),
        //         .product(
        //             name: "TestFlows",
        //             package: "TestFlows"
        //         ),
        //     ]
        // ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
