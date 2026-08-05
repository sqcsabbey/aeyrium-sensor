// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "aeyrium_sensor",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "aeyrium-sensor", targets: ["aeyrium_sensor"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "aeyrium_sensor",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/aeyrium_sensor")
            ]
        )
    ]
)
