import SpriteKit
import UIKit

/// 场景回调全部发生在主线程（SpriteKit 渲染线程即主线程），统一标注 @MainActor，
/// 便于 Swift 6 严格并发下与 ViewModel 侧对齐。
@MainActor
protocol CatMergeSceneDelegate: AnyObject {
    func catScene(_ scene: CatMergeScene, didChangeScore score: Int)
    func catScene(_ scene: CatMergeScene, didChangeNext species: CatSpecies)
    func catScene(_ scene: CatMergeScene, didMergeInto species: CatSpecies, gained: Int)
    func catSceneDidEnd(_ scene: CatMergeScene, finalScore: Int, topSpecies: CatSpecies)
}

/// 主场景：掉落 → 碰撞 → 同级合成 → 计分 → 越界判负。
///
/// 架构说明：
/// - 场景只负责"物理 + 表现"，分数与界面状态通过 delegate 上抛给 SwiftUI 的 ViewModel；
/// - 合并统一延迟到 `didSimulatePhysics` 处理，避免在物理回调里修改节点树导致崩溃；
/// - 无任何网络调用，场景可在飞行模式下完整运行。
/// SKScene 继承自 UIResponder（本身即 @MainActor），子类显式标注保持一致。
@MainActor
final class CatMergeScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - 公开状态

    private(set) var score: Int = 0
    private(set) var nextSpecies: CatSpecies = .kitten
    private(set) var topSpecies: CatSpecies = .kitten
    private(set) var isGameOver: Bool = false

    weak var gameDelegate: CatMergeSceneDelegate?

    // MARK: - 私有状态

    private var previewNode: CatNode?
    private var pendingMerges: [(a: CatNode, b: CatNode)] = []
    private var overflowTime: [ObjectIdentifier: TimeInterval] = [:]
    private var lastDropTime: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    private var walls: [SKNode] = []
    private var dangerLine: SKShapeNode?
    private var dropLineY: CGFloat = 0
    private var dangerLineY: CGFloat = 0
    private var hasBootstrapped = false

    // MARK: - 生命周期

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: GameConfig.gravity)
        physicsWorld.contactDelegate = self
        rebuildArena()
        if !hasBootstrapped {
            startNewRound()
            hasBootstrapped = true
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildArena()
    }

    // MARK: - 场地构建

    private func rebuildArena() {
        walls.forEach { $0.removeFromParent() }
        walls.removeAll()
        dangerLine?.removeFromParent()
        dangerLine = nil

        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return }

        dropLineY = height - GameConfig.dropLineInset
        dangerLineY = height - GameConfig.dangerLineInset

        // 三面墙：左、右、底。顶部开放，允许猫短暂越过警戒线
        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: width, y: 0))

        let left = SKNode()
        left.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: height * 3))

        let right = SKNode()
        right.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: width, y: 0), to: CGPoint(x: width, y: height * 3))

        for wall in [floor, left, right] {
            guard let body = wall.physicsBody else { continue }
            body.categoryBitMask = GameConfig.Category.wall.rawValue
            body.collisionBitMask = GameConfig.Category.cat.rawValue
            body.contactTestBitMask = 0
            body.restitution = 0
            body.friction = 0.35
            addChild(wall)
            walls.append(wall)
        }

        // 警戒线（虚线 + 呼吸动画）
        let line = SKShapeNode()
        let path = CGMutablePath()
        var x: CGFloat = 8
        while x < width - 8 {
            path.move(to: CGPoint(x: x, y: dangerLineY))
            path.addLine(to: CGPoint(x: min(x + 8, width - 8), y: dangerLineY))
            x += 14
        }
        line.path = path
        line.strokeColor = UIColor.systemPink.withAlphaComponent(0.45)
        line.lineWidth = 2
        line.zPosition = -1
        addChild(line)
        dangerLine = line

        if !UIAccessibility.isReduceMotionEnabled {
            let breathe = SKAction.sequence([
                .fadeAlpha(to: 0.25, duration: 0.9),
                .fadeAlpha(to: 0.6, duration: 0.9)
            ])
            line.run(.repeatForever(breathe))
        }

        // 尺寸变化后把预览球拉回场内
        if let preview = previewNode {
            preview.position = CGPoint(x: clampedX(preview.position.x), y: dropLineY)
        } else {
            buildPreview()
        }
    }

    // MARK: - 回合控制

    func startNewRound() {
        isGameOver = false
        score = 0
        topSpecies = .kitten
        pendingMerges.removeAll()
        overflowTime.removeAll()
        lastFrameTime = 0

        children.compactMap { $0 as? CatNode }.forEach { $0.removeFromParent() }

        physicsWorld.speed = 1.0
        nextSpecies = CatSpecies.randomSpawn()
        buildPreview()

        gameDelegate?.catScene(self, didChangeScore: 0)
        gameDelegate?.catScene(self, didChangeNext: nextSpecies)
    }

    private func buildPreview() {
        previewNode?.removeFromParent()
        let preview = CatNode(species: nextSpecies, isPreview: true)
        preview.position = CGPoint(x: size.width / 2, y: dropLineY)
        addChild(preview)
        previewNode = preview
    }

    private func advanceNextSpecies() {
        nextSpecies = CatSpecies.randomSpawn()
        guard let preview = previewNode else { buildPreview(); return }
        let newTexture = CatTextureFactory.texture(for: nextSpecies)
        let side = nextSpecies.radius * 2
        preview.texture = newTexture
        preview.size = CGSize(width: side, height: side)
        preview.accessibilityLabel = "下一只：\(nextSpecies.displayName)"
        preview.setScale(0.7)
        preview.run(.scale(to: 1.0, duration: 0.18))
        gameDelegate?.catScene(self, didChangeNext: nextSpecies)
    }

    // MARK: - 输入

    private func clampedX(_ x: CGFloat) -> CGFloat {
        let r = nextSpecies.radius
        return min(max(x, r + 2), max(r + 2, size.width - r - 2))
    }

    private func movePreview(to x: CGFloat) {
        guard !isGameOver, let preview = previewNode else { return }
        preview.position = CGPoint(x: clampedX(x), y: dropLineY)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), !isGameOver else { return }
        movePreview(to: point.x)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), !isGameOver else { return }
        movePreview(to: point.x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), !isGameOver else { return }
        movePreview(to: point.x)
        drop(at: point.x)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 来电 / 控制中心下拉等中断：不掉落，避免误操作
    }

    private func drop(at x: CGFloat) {
        let now = CACurrentMediaTime()
        guard now - lastDropTime >= GameConfig.dropCooldown else { return }
        lastDropTime = now

        let cat = CatNode(species: nextSpecies)
        cat.position = CGPoint(x: clampedX(x), y: dropLineY)
        cat.spawnTime = now
        addChild(cat)
        cat.playSpawnAnimation()

        HapticsManager.drop()
        SoundManager.shared.play(.drop)
        advanceNextSpecies()
    }

    // MARK: - 帧循环

    override func update(_ currentTime: TimeInterval) {
        guard lastFrameTime > 0 else { lastFrameTime = currentTime; return }
        let delta = min(currentTime - lastFrameTime, 0.05)   // 卡顿保护：单帧最多 50ms
        lastFrameTime = currentTime
        guard !isGameOver else { return }
        checkOverflow(delta: delta)
    }

    override func didSimulatePhysics() {
        processMerges()
    }

    // MARK: - 碰撞与合并

    /// 物理回调由 SpriteKit 在主线程派发；协议本身是非隔离的，
    /// 这里用 nonisolated + assumeIsolated 显式回到 MainActor，兼容 Swift 6 严格并发。
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        let nodeA = contact.bodyA.node as? CatNode
        let nodeB = contact.bodyB.node as? CatNode
        MainActor.assumeIsolated {
            guard let a = nodeA, let b = nodeB else { return }
            guard !a.isPreview, !b.isPreview else { return }
            guard a.canMerge, b.canMerge, a.species == b.species else { return }
            pendingMerges.append((a, b))
        }
    }

    private func processMerges() {
        guard !pendingMerges.isEmpty, !isGameOver else {
            pendingMerges.removeAll()
            return
        }

        var handled = Set<ObjectIdentifier>()

        for pair in pendingMerges {
            let a = pair.a
            let b = pair.b
            guard a.parent != nil, b.parent != nil, a.canMerge, b.canMerge else { continue }

            let idA = ObjectIdentifier(a)
            let idB = ObjectIdentifier(b)
            guard !handled.contains(idA), !handled.contains(idB) else { continue }
            handled.insert(idA)
            handled.insert(idB)

            a.canMerge = false
            b.canMerge = false

            let midpoint = CGPoint(x: (a.position.x + b.position.x) / 2,
                                   y: (a.position.y + b.position.y) / 2)
            let level = a.species

            a.removeFromParent()
            b.removeFromParent()
            overflowTime[idA] = nil
            overflowTime[idB] = nil

            if let evolved = level.next {
                let gained = evolved.scoreValue
                score += gained
                topSpecies = max(topSpecies, evolved)
                spawnCat(evolved, at: midpoint)
                playMergeEffect(at: midpoint, species: evolved, gained: gained)
                SoundManager.shared.play(.merge(evolved.rawValue))
                HapticsManager.merge(level: evolved.rawValue)
                gameDelegate?.catScene(self, didMergeInto: evolved, gained: gained)
                gameDelegate?.catScene(self, didChangeScore: score)
            } else {
                // 两只猫王相撞：双双消失，给一笔大额奖励
                let gained = GameConfig.kingBonus
                score += gained
                playMergeEffect(at: midpoint, species: .king, gained: gained, isClash: true)
                SoundManager.shared.play(.kingClash)
                HapticsManager.kingClash()
                gameDelegate?.catScene(self, didMergeInto: .king, gained: gained)
                gameDelegate?.catScene(self, didChangeScore: score)
            }
        }

        pendingMerges.removeAll()
    }

    private func spawnCat(_ species: CatSpecies, at position: CGPoint) {
        let cat = CatNode(species: species)
        cat.position = position
        cat.spawnTime = CACurrentMediaTime()
        addChild(cat)
        cat.playSpawnAnimation()
    }

    // MARK: - 特效

    private func playMergeEffect(at point: CGPoint, species: CatSpecies, gained: Int, isClash: Bool = false) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        // 光环
        let halo = SKShapeNode(circleOfRadius: species.radius * 0.9)
        halo.position = point
        halo.strokeColor = UIColor.systemPink.withAlphaComponent(0.8)
        halo.lineWidth = 3
        halo.zPosition = 5
        addChild(halo)
        halo.run(.sequence([
            .group([.scale(to: 2.0, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))

        // 加分飘字
        let label = SKLabelNode(text: "+\(gained)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = isClash ? 28 : 20
        label.fontColor = UIColor(hex: 0xFF6B8A)
        label.position = CGPoint(x: point.x, y: point.y + species.radius * 0.6)
        label.zPosition = 6
        addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: 46, duration: 0.7),
                .fadeOut(withDuration: 0.7)
            ]),
            .removeFromParent()
        ]))

        guard !reduceMotion else { return }

        // 粒子：小圆点四散
        let particleCount = isClash ? 20 : 10
        for index in 0..<particleCount {
            let dot = SKShapeNode(circleOfRadius: species.radius * 0.09)
            dot.fillColor = species.bottomColor
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = 4
            addChild(dot)

            let angle = CGFloat(index) / CGFloat(particleCount) * 2 * .pi + .pi / 4
            let distance = species.radius * (isClash ? 2.6 : 1.8)
            let target = CGPoint(x: point.x + cos(angle) * distance,
                                 y: point.y + sin(angle) * distance)
            dot.run(.sequence([
                .group([
                    .move(to: target, duration: 0.42),
                    .scale(to: 0.2, duration: 0.42),
                    .fadeOut(withDuration: 0.42)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - 判负

    private func checkOverflow(delta: TimeInterval) {
        let now = CACurrentMediaTime()
        for node in children.compactMap({ $0 as? CatNode }) where !node.isPreview {
            let id = ObjectIdentifier(node)
            let isSettled = now - node.spawnTime > GameConfig.gracePeriod
            let top = node.position.y + node.species.radius

            if isSettled && top > dangerLineY {
                overflowTime[id, default: 0] += delta
                if overflowTime[id] ?? 0 >= GameConfig.overflowLimit {
                    endGame()
                    return
                }
            } else {
                overflowTime[id] = nil
            }
        }
    }

    private func endGame() {
        guard !isGameOver else { return }
        isGameOver = true
        physicsWorld.speed = 0.25
        previewNode?.run(.fadeOut(withDuration: 0.2))
        SoundManager.shared.play(.gameOver)
        HapticsManager.gameOver()
        gameDelegate?.catSceneDidEnd(self, finalScore: score, topSpecies: topSpecies)
    }
}
