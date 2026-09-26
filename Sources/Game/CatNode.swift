import SpriteKit
import UIKit

/// 一只猫。既是物理体也是视觉节点。
/// SKNode 继承自 UIResponder，本身即 @MainActor，此处显式标注保持一致。
@MainActor
final class CatNode: SKSpriteNode {

    let species: CatSpecies
    /// 本帧内是否仍可参与合并（防止同一只猫在一帧内被合并两次）
    var canMerge = true
    /// 生成时刻，用于宽限期与越界计时
    var spawnTime: TimeInterval = 0
    /// 预览球（跟随手指，不参与物理）
    let isPreview: Bool

    init(species: CatSpecies, isPreview: Bool = false) {
        self.species = species
        self.isPreview = isPreview
        let texture = CatTextureFactory.texture(for: species)
        let side = species.radius * 2
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))

        self.name = "cat-\(species.rawValue)"
        // VoiceOver：等级用名称而非仅靠颜色 / 尺寸区分
        self.accessibilityLabel = species.displayName

        guard !isPreview else {
            alpha = 0.82
            zPosition = 10
            return
        }

        let body = SKPhysicsBody(circleOfRadius: species.radius * 0.96)
        body.restitution = 0.10          // 轻微回弹，避免"果冻感"
        body.friction = 0.42
        body.linearDamping = 0.06
        body.angularDamping = 0.35
        body.density = GameConfig.density
        body.allowsRotation = true
        body.categoryBitMask = GameConfig.Category.cat.rawValue
        body.collisionBitMask = GameConfig.Category.cat.rawValue | GameConfig.Category.wall.rawValue
        body.contactTestBitMask = GameConfig.Category.cat.rawValue
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 出生动画：轻微放大回弹
    func playSpawnAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            alpha = 1
            return
        }
        setScale(0.35)
        let pop = SKAction.sequence([
            .scale(to: 1.12, duration: 0.12),
            .scale(to: 1.0, duration: 0.10)
        ])
        pop.timingMode = .easeOut
        run(pop)
    }
}
