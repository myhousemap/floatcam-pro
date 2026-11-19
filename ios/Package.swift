// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FloatCamPro",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FloatCamPro",
            targets: ["FloatCamPro"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FloatCamPro",
            path: "FloatCamPro"
        )
    ]
)
