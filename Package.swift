// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-formula",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FormulaCore", targets: ["FormulaCore"]),
        .library(name: "FormulaLCE", targets: ["FormulaLCE"]),
        .library(name: "FormulaSwiftUI", targets: ["FormulaSwiftUI"]),
        .executable(name: "FormulaSample", targets: ["FormulaSample"])
    ],
    targets: [
        .target(name: "FormulaCore"),
        .target(name: "FormulaLCE"),
        .target(name: "FormulaSwiftUI", dependencies: ["FormulaCore"]),
        .executableTarget(name: "FormulaSample", dependencies: ["FormulaCore", "FormulaLCE", "FormulaSwiftUI"]),
        .testTarget(name: "FormulaCoreTests", dependencies: ["FormulaCore"]),
        .testTarget(name: "FormulaLCETests", dependencies: ["FormulaLCE"]),
        .testTarget(name: "FormulaSampleTests", dependencies: ["FormulaSample"])
    ]
)
