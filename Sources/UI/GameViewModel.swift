import SpriteKit
import UIKit

/// SwiftUI 与 SKScene 之间的桥接层。
/// 场景负责物理与表现，ViewModel 负责界面状态与播报。
@MainActor
final class GameViewModel: ObservableObject {

    let scene: CatMergeScene

    @Published private(set) var score: Int = 0
    @Published private(set) var nextSpecies: CatSpecies = .kitten
    @Published private(set) var topSpecies: CatSpecies = .kitten
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var isNewBest: Bool = false
    @Published private(set) var bestScore: Int = ScoreStore.shared.bestScore
    @Published var isPaused: Bool = false {
        didSet { scene.isPaused = isPaused }
    }

    init() {
        let scene = CatMergeScene(size: CGSize(width: GameConfig.designWidth, height: 640))
        scene.scaleMode = .resizeFill
        self.scene = scene
        scene.gameDelegate = self
        self.bestScore = ScoreStore.shared.bestScore
    }

    func restart() {
        isGameOver = false
        isNewBest = false
        isPaused = false
        score = 0
        topSpecies = .kitten
        scene.isPaused = false
        scene.startNewRound()
        announce("新的一局开始")
    }

    func togglePause() {
        isPaused.toggle()
        announce(isPaused ? "已暂停" : "继续游戏")
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

// MARK: - CatMergeSceneDelegate

extension GameViewModel: CatMergeSceneDelegate {
    func catScene(_ scene: CatMergeScene, didChangeScore score: Int) {
        self.score = score
    }

    func catScene(_ scene: CatMergeScene, didChangeNext species: CatSpecies) {
        self.nextSpecies = species
    }

    func catScene(_ scene: CatMergeScene, didMergeInto species: CatSpecies, gained: Int) {
        self.topSpecies = max(self.topSpecies, species)
        announce("合成\(species.displayName)，加\(gained)分")
    }

    func catSceneDidEnd(_ scene: CatMergeScene, finalScore: Int, topSpecies: CatSpecies) {
        self.topSpecies = topSpecies
        self.isGameOver = true
        self.isNewBest = ScoreStore.shared.submit(score: finalScore, topSpecies: topSpecies)
        self.bestScore = ScoreStore.shared.bestScore
        announce("游戏结束，本局\(finalScore)分")
    }
}
