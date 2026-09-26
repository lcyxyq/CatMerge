import SwiftUI

/// 合成猫 · CatMerge
/// 移植自「合成大西瓜」玩法（Suika-style merge）的猫主题版本。
/// 原始参考项目：
///  - Asterless/MGPIC2025（合成猫 Meme，Apache-2.0）
///  - LordSpecial/suika-game（matter.js 复刻，Unlicense，含 cats theme）
/// 本工程为 Swift / SpriteKit 原生重写，猫脸素材由代码程序化绘制，不复用上游图片资源。
/// 全程离线：无网络请求、无第三方 SDK、无分析统计。

@main
struct CatMergeApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                // 同时支持浅色 / 深色外观，不做强制
                .preferredColorScheme(nil)
        }
    }
}
