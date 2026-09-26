import UIKit

/// 猫的 11 个等级：0 最小 → 10 最大（猫王）。
///
/// 说明：名称、半径、配色、分值均为本项目原创配置，
/// 便于 App Store 上架时避免与商业作品素材产生混淆。
enum CatSpecies: Int, CaseIterable, Codable, Comparable, Identifiable, Sendable {

    case kitten  = 0   // 奶猫崽
    case marsh       // 棉花糖
    case pudding     // 布丁
    case orange      // 橘子
    case tabby       // 狸花
    case cow         // 奶牛
    case calico      // 三花
    case british     // 蓝胖子
    case ragdoll     // 布偶
    case maine       // 缅因
    case king        // 猫王

    // MARK: - 基础属性

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .kitten:  return "奶猫崽"
        case .marsh:   return "棉花糖"
        case .pudding: return "布丁"
        case .orange:  return "橘子"
        case .tabby:   return "狸花"
        case .cow:     return "奶牛"
        case .calico:  return "三花"
        case .british: return "蓝胖子"
        case .ragdoll: return "布偶"
        case .maine:   return "缅因"
        case .king:    return "猫王"
        }
    }

    /// 设计基准宽度 390pt 下的半径（pt）
    var radius: CGFloat {
        switch self {
        case .kitten:  return 13
        case .marsh:   return 17.5
        case .pudding: return 23
        case .orange:  return 29.5
        case .tabby:   return 37
        case .cow:     return 45.5
        case .calico:  return 55
        case .british: return 65.5
        case .ragdoll: return 77
        case .maine:   return 89
        case .king:    return 102
        }
    }

    /// 合成出这一级猫时获得的分数
    var scoreValue: Int {
        switch self {
        case .kitten:  return 1
        case .marsh:   return 3
        case .pudding: return 6
        case .orange:  return 10
        case .tabby:   return 15
        case .cow:     return 21
        case .calico:  return 28
        case .british: return 36
        case .ragdoll: return 45
        case .maine:   return 55
        case .king:    return 120
        }
    }

    /// 头部渐变上色 / 下色（马卡龙系，避免单一色相区分等级）
    var topColor: UIColor {
        UIColor(hex: palette.0)
    }

    var bottomColor: UIColor {
        UIColor(hex: palette.1)
    }

    /// 身体描边颜色：不依赖颜色单独传达等级，另有文字标签与尺寸差异
    var outlineColor: UIColor {
        UIColor(hex: 0x5C4433).withAlphaComponent(0.28)
    }

    private var palette: (UInt32, UInt32) {
        switch self {
        case .kitten:  return (0xFFF7D6, 0xFFD98A)
        case .marsh:   return (0xFFE4EF, 0xFFAFCC)
        case .pudding: return (0xFFEBCB, 0xFFC07A)
        case .orange:  return (0xFFD9B8, 0xFF9E5E)
        case .tabby:   return (0xEDE6D2, 0xBFAE82)
        case .cow:     return (0xFFFFFF, 0xC9CFD6)
        case .calico:  return (0xFFE1B8, 0xE08A5B)
        case .british: return (0xDCE8F5, 0x8FA9C4)
        case .ragdoll: return (0xF5E8F9, 0xC9A7DC)
        case .maine:   return (0xE7DDCB, 0x9C8B6E)
        case .king:    return (0xFFEBAE, 0xE0B23C)
        }
    }

    // MARK: - 关系与生成

    /// 合成后的下一级（猫王返回 nil）
    var next: CatSpecies? { CatSpecies(rawValue: rawValue + 1) }

    static let maxLevel: CatSpecies = .king

    /// 可掉落的等级池与权重（只掉落前 5 级，保证开局节奏）
    private static let spawnPool: [CatSpecies] = [.kitten, .marsh, .pudding, .orange, .tabby]
    private static let spawnWeights: [Double] = [0.34, 0.27, 0.20, 0.12, 0.07]

    static func randomSpawn() -> CatSpecies {
        let total = spawnWeights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        for (index, weight) in spawnWeights.enumerated() {
            roll -= weight
            if roll <= 0 { return spawnPool[index] }
        }
        return spawnPool[0]
    }

    // MARK: - Comparable

    static func < (lhs: CatSpecies, rhs: CatSpecies) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - UIColor 十六进制便捷初始化

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
