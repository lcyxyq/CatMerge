// swift-tools-version: 6.0
// CatMerge 的 SwiftPM 描述文件。
//
// 用途有二：
// 1. xtool（跨平台 Xcode 替代品）在 Linux / WSL 上直接构建并部署到真机时使用；
// 2. 让工程不依赖 .xcodeproj 也能被标准 Swift 工具链消费。
//
// 注意：Xcode 侧仍使用 project.yml（xcodegen）生成的工程，两条链路共用 Sources/ 下的同一份源码。
import PackageDescription

let package = Package(
    name: "CatMerge",
    platforms: [
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "CatMerge",
            path: "Sources"
        )
    ]
)
