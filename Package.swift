// swift-tools-version: 6.0
import PackageDescription

// Portable checks compile the actual app sources. SwiftUI and Keychain require Xcode/iOS.
let package = Package(
    name: "SkinCareContractChecks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SkinCare", path: "SkinCare", sources: [
            "Models/Enums.swift", "Models/AnalysisModels.swift", "Models/AuthModels.swift", "Models/SymptomProfile.swift",
            "Networking/APIRequest.swift", "Networking/APIError.swift", "Networking/APIClient.swift",
            "Networking/HTTPTransport.swift", "Networking/Endpoints.swift", "Networking/MultipartFormData.swift",
            "Networking/AuthTokenManager.swift", "Networking/RefreshTokenStore.swift",
            "Core/AnalysisDisplay.swift", "Core/PollingPolicy.swift", "Core/Formatting.swift", "Core/CareCatalog.swift",
            "App/AppCopy.swift", "App/AppConfig.swift"
        ], resources: [.process("Resources/Care/care-guide.json")]),
        .testTarget(name: "ContractTests", dependencies: ["SkinCare"], path: "SkinCareTests", sources: [
            "DecodingTests.swift", "APIClientTests.swift", "PollingPolicyTests.swift", "GenerationTests.swift",
            "ClassificationExplanationTests.swift", "MobileParityTests.swift"
        ], resources: [.process("Fixtures")])
    ]
)
