import SpriteKit
import UIKit

/// 全局数值与物理参数。
/// 所有可调项集中在此处，便于手感调优与 A/B。
enum GameConfig {

    // MARK: - 场地

    /// 设计基准宽度（iPhone 14/15 逻辑宽度），仅用于参考
    static let designWidth: CGFloat = 390
    /// 场地上方预留：掉落线距顶部
    static let dropLineInset: CGFloat = 48
    /// 警戒线距顶部（猫顶超过此线并停留即判负）
    static let dangerLineInset: CGFloat = 138

    // MARK: - 物理

    /// 重力加速度（pt/s²）。
    /// 注意：SpriteKit 的重力属"手感参数"而非真实物理，默认 -9.8 在游戏里几乎不动。
    /// 这里按"从顶部 500pt 约 0.65 秒落地"标定为 -2400，与合成类游戏手感一致。
    static let gravity: CGFloat = -2400
    /// 掉落冷却，防止连点刷屏
    static let dropCooldown: TimeInterval = 0.42
    /// 猫的物理体密度：越大越"沉"，大猫自然更重
    static let density: CGFloat = 0.0018

    // MARK: - 判负

    /// 新生成猫的宽限期（期间不参与越界判定）
    static let gracePeriod: TimeInterval = 1.0
    /// 越界持续多久判负
    static let overflowLimit: TimeInterval = 1.6
    /// 两只猫王相撞的额外奖励
    static let kingBonus: Int = 300

    // MARK: - 碰撞分类

    enum Category: UInt32 {
        case cat  = 0x1
        case wall = 0x2
    }
}
