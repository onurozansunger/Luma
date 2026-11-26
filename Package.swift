// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Luma", platforms: [.macOS(.v14)],
    products: [.executable(name: "Luma", targets: ["LumaApp"]), .executable(name: "LumaAgent", targets: ["LumaAgent"]), .executable(name: "LumaGateway", targets: ["LumaGateway"])],
    targets: [
        .target(name: "LumaCore"),
        .executableTarget(name: "LumaApp", dependencies: ["LumaCore"]),
        .executableTarget(name: "LumaAgent", dependencies: ["LumaCore"]),
        .executableTarget(name: "LumaGateway", dependencies: ["LumaCore"]),
        .testTarget(name: "LumaCoreTests", dependencies: ["LumaCore"])
    ], swiftLanguageModes: [.v5]
)
