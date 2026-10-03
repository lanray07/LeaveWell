// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeaveWellCore",
    products: [.library(name: "LeaveWellCore", targets: ["LeaveWellCore"])],
    targets: [
        .target(name: "LeaveWellCore", path: "LeaveWell/Core"),
        .testTarget(name: "LeaveWellCoreTests", dependencies: ["LeaveWellCore"], path: "Tests/Core")
    ]
)
