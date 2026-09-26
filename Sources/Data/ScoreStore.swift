import Foundation

/// 本地成绩存档。
///
/// 完全离线：只写 UserDefaults，不联网、不上传、不做云同步。
/// 数据结构保持轻量，便于将来无痛迁移到 SwiftData 或文件存储。
@MainActor
final class ScoreStore: ObservableObject {

    struct Record: Codable, Identifiable {
        let id: UUID
        let score: Int
        let topSpecies: String
        let date: Date

        init(score: Int, topSpecies: CatSpecies) {
            self.id = UUID()
            self.score = score
            self.topSpecies = topSpecies.displayName
            self.date = Date()
        }
    }

    static let shared = ScoreStore()

    @Published private(set) var bestScore: Int
    @Published private(set) var records: [Record]

    private let bestKey = "catmerge.bestScore.v1"
    private let recordsKey = "catmerge.records.v1"
    private let maxRecords = 20

    private init() {
        let defaults = UserDefaults.standard
        self.bestScore = defaults.integer(forKey: bestKey)
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([Record].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }
    }

    /// 提交一局成绩，返回是否刷新了最高分
    @discardableResult
    func submit(score: Int, topSpecies: CatSpecies) -> Bool {
        guard score > 0 else { return false }
        let isNewBest = score > bestScore
        if isNewBest {
            bestScore = score
            UserDefaults.standard.set(score, forKey: bestKey)
        }
        records.insert(Record(score: score, topSpecies: topSpecies), at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        persist()
        return isNewBest
    }

    func clearAll() {
        bestScore = 0
        records = []
        UserDefaults.standard.removeObject(forKey: bestKey)
        UserDefaults.standard.removeObject(forKey: recordsKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
    }
}
