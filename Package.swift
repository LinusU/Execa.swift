// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Execa",
    products: [
        .library(name: "Execa", targets: ["Execa"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit", from: "6.2.3"),
    ],
    targets: [
        .target(name: "Execa", dependencies: ["PromiseKit"]),
        .testTarget(name: "ExecaTests", dependencies: ["Execa"]),
    ]
)
