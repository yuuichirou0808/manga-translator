// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MangaPDFTranslator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MangaPDFTranslator", targets: ["MangaPDFTranslator"])
    ],
    targets: [
        .executableTarget(
            name: "MangaPDFTranslator",
            path: "Sources/MangaPDFTranslator"
        )
    ]
)
