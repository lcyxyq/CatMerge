import AVFoundation
import UIKit

/// 音效管理器。
///
/// 全部音效在运行时用数字合成（正弦 / 三角波 + ADSR 包络）并写成 WAV 交给 AVAudioPlayer，
/// 好处：不引入音频素材版权、不增加 App 体积、可按等级实时变调。
/// 全程离线，不访问网络与磁盘之外的任何资源。
/// 合成与播放均在主线程完成。
@MainActor
final class SoundManager {

    static let shared = SoundManager()

    enum Effect: Hashable {
        case drop
        case merge(Int)      // 参数为合成后的等级
        case kingClash
        case gameOver

        var key: String {
            switch self {
            case .drop:        return "drop"
            case .merge(let l): return "merge-\(l)"
            case .kingClash:   return "clash"
            case .gameOver:    return "over"
            }
        }
    }

    var isEnabled: Bool = true

    private var players: [String: AVAudioPlayer] = [:]
    private let sampleRate: Double = 44100

    private init() {}

    // MARK: - 播放

    /// 播放。调用方均在主线程（SpriteKit 渲染 / SwiftUI 事件），同步执行即可。
    func play(_ effect: Effect) {
        guard isEnabled else { return }
        let player = players[effect.key] ?? buildPlayer(for: effect)
        players[effect.key] = player
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    private func buildPlayer(for effect: Effect) -> AVAudioPlayer? {
        let samples = render(effect)
        let data = WAVBuilder.data(samples: samples, sampleRate: Int(sampleRate))
        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        return player
    }

    // MARK: - 波形合成

    private func render(_ effect: Effect) -> [Float] {
        switch effect {
        case .drop:
            // 短促的"啵"：频率快速下滑，极短包络
            return Self.synthesize(duration: 0.11,
                                   frequency: { t in 540 - 260 * t },
                                   envelope: { t in pow(1 - t, 2.2) },
                                   wave: Self.sine)

        case .merge(let level):
            // "喵~"：先上扬后回落，带轻微颤音，等级越高音越低沉
            let base = 620 - Double(min(level, 10)) * 34
            return Self.synthesize(duration: 0.42,
                                   frequency: { t in
                                       let arc = sin(.pi * t)                 // 0 → 1 → 0
                                       let vibrato = 1 + 0.035 * sin(2 * .pi * 13 * t)
                                       return base * (0.78 + 0.46 * arc) * vibrato
                                   },
                                   envelope: { t in
                                       let attack = min(t / 0.08, 1.0)
                                       let release = pow(1 - t, 1.6)
                                       return attack * release * 0.9
                                   },
                                   wave: Self.catVoice)

        case .kingClash:
            return Self.synthesize(duration: 0.55,
                                   frequency: { t in 300 + 620 * sin(.pi * t) },
                                   envelope: { t in pow(1 - t, 1.3) * 0.85 },
                                   wave: Self.catVoice)

        case .gameOver:
            // 下行"呜"：失败提示
            return Self.synthesize(duration: 0.7,
                                   frequency: { t in 420 - 240 * t },
                                   envelope: { t in
                                       let attack = min(t / 0.05, 1.0)
                                       return attack * pow(1 - t, 1.2) * 0.8
                                   },
                                   wave: Self.triangle)
        }
    }

    private static func synthesize(duration: Double,
                                   frequency: (Double) -> Double,
                                   envelope: (Double) -> Double,
                                   wave: (Double) -> Double) -> [Float] {
        let sr = 44100.0
        let count = Int(duration * sr)
        var output = [Float]()
        output.reserveCapacity(count)
        var phase = 0.0
        for i in 0..<count {
            let progress = Double(i) / Double(count)
            let freq = frequency(progress)
            phase += 2 * .pi * freq / sr
            output.append(Float(wave(phase) * envelope(progress)))
        }
        return output
    }

    // 纯正弦
    private static func sine(_ phase: Double) -> Double { sin(phase) }

    // 猫叫音色：基频 + 二次谐波 + 少量三次谐波
    private static func catVoice(_ phase: Double) -> Double {
        sin(phase) * 0.62 + sin(phase * 2) * 0.26 + sin(phase * 3) * 0.10
    }

    // 三角波
    private static func triangle(_ phase: Double) -> Double {
        let p = phase.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)
        return 4 * abs(p - 0.5) - 1
    }
}

// MARK: - 内存 WAV 封装

private enum WAVBuilder {
    static func data(samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.appendLE(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.appendLE(UInt32(16))                 // fmt chunk 长度
        data.appendLE(UInt16(1))                  // PCM
        data.appendLE(UInt16(1))                  // 单声道
        data.appendLE(UInt32(sampleRate))
        data.appendLE(UInt32(sampleRate * 2))     // byte rate
        data.appendLE(UInt16(2))                  // block align
        data.appendLE(UInt16(16))                 // 位深
        data.append(contentsOf: "data".utf8)
        data.appendLE(UInt32(samples.count * 2))
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            data.appendLE(UInt16(bitPattern: Int16(clamped * 32767)))
        }
        return data
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}
