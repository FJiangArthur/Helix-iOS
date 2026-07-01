// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NativeHelix",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HelixCore", targets: ["HelixCore"]),
        .library(name: "HelixPersistence", targets: ["HelixPersistence"]),
        .library(name: "HelixAI", targets: ["HelixAI"]),
        .library(name: "HelixSpeech", targets: ["HelixSpeech"]),
        .library(name: "HelixConversation", targets: ["HelixConversation"]),
        .library(name: "HelixG1", targets: ["HelixG1"]),
        .library(name: "HelixRuntime", targets: ["HelixRuntime"])
    ],
    targets: [
        .target(name: "HelixCore"),
        .target(name: "HelixPersistence", dependencies: ["HelixCore"]),
        .target(name: "HelixAI", dependencies: ["HelixCore"]),
        .target(name: "HelixSpeech", dependencies: ["HelixCore"]),
        .target(name: "HelixG1", dependencies: ["HelixCore"]),
        .target(
            name: "HelixConversation",
            dependencies: ["HelixCore", "HelixAI", "HelixSpeech", "HelixG1", "HelixPersistence"]
        ),
        .target(
            name: "HelixRuntime",
            dependencies: ["HelixCore", "HelixAI", "HelixConversation", "HelixG1", "HelixPersistence"]
        ),
        .testTarget(
            name: "HelixConversationTests",
            dependencies: [
                "HelixCore",
                "HelixAI",
                "HelixSpeech",
                "HelixConversation",
                "HelixG1",
                "HelixPersistence",
                "HelixRuntime"
            ]
        )
    ]
)
