import UIKit

/// 触觉反馈。
///
/// 遵循 HIG：反馈强度与事件重要性匹配，不滥用；
/// 系统"减弱动态效果"开启时保持轻反馈（触觉本身不属于动态效果，但强度降级更友好）。
@MainActor
enum HapticsManager {

    static var isEnabled: Bool = true

    static func drop() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func merge(level: Int) {
        guard isEnabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch level {
        case 0...3:   style = .light
        case 4...7:   style = .medium
        default:      style = .heavy
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        // 等级越高，强度越明显（上限 1.0）
        generator.impactOccurred(intensity: min(0.5 + CGFloat(level) * 0.06, 1.0))
    }

    static func kingClash() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func gameOver() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}
