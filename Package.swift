// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GridView",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15)
    ],
    products: [
        .library(name: "GridView",
                 targets: ["GridView"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "GridView",
                dependencies: [])
    ]
)
