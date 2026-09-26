import SpriteKit
import UIKit

/// 程序化绘制猫脸贴图。
///
/// 设计要点：
/// 1. 不引入任何外部图片资源 —— 上游仓库的猫 Meme 图片多为网络梗图，版权不明，
///    自绘可彻底规避素材风险，也省去 1x/2x/3x 切图与 App 体积。
/// 2. 纹理按等级缓存，避免每次生成猫都走一次离屏渲染。
/// 3. 同时暴露 UIImage，供 SwiftUI 的 HUD 复用同一套视觉（下一只猫预览）。
/// 只在主线程调用（SpriteKit 渲染 / SwiftUI 绘制），纹理缓存无需加锁。
@MainActor
enum CatTextureFactory {

    private static var textureCache: [CatSpecies: SKTexture] = [:]
    private static var imageCache: [CatSpecies: UIImage] = [:]

    // MARK: - 对外接口

    static func texture(for species: CatSpecies) -> SKTexture {
        if let cached = textureCache[species] { return cached }
        let texture = SKTexture(image: image(for: species))
        texture.filteringMode = .linear
        textureCache[species] = texture
        return texture
    }

    static func image(for species: CatSpecies) -> UIImage {
        if let cached = imageCache[species] { return cached }
        let side = species.radius * 2
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3          // 保证 3x 屏幕下边缘不糊
        format.opaque = false     // 保留透明背景
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            draw(species: species, in: CGRect(x: 0, y: 0, width: side, height: side), context: context)
        }
        imageCache[species] = image
        return image
    }

    // MARK: - 绘制

    private static func draw(species: CatSpecies, in rect: CGRect, context: UIGraphicsImageRendererContext) {
        let cg = context.cgContext
        let r = rect.width / 2

        // 头部略小于画布：给耳朵留出空间
        let headR = r * 0.80
        let headCenter = CGPoint(x: rect.midX, y: rect.midY + r * 0.08)

        // 1) 耳朵（画在头之后会被头盖住底部，接缝自然）
        drawEar(cg: cg, center: headCenter, radius: headR, angle: 145, species: species)
        drawEar(cg: cg, center: headCenter, radius: headR, angle: 35, species: species)

        // 2) 头（径向渐变球体）
        let headRect = CGRect(x: headCenter.x - headR,
                              y: headCenter.y - headR,
                              width: headR * 2,
                              height: headR * 2)
        cg.saveGState()
        cg.addEllipse(in: headRect)
        cg.clip()
        let colors = [species.topColor.cgColor, species.bottomColor.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors,
                                     locations: [0.0, 1.0]) {
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: headRect.minX, y: headRect.minY),
                                  end: CGPoint(x: headRect.midX, y: headRect.maxY),
                                  options: [])
        }
        cg.restoreGState()

        // 3) 描边
        cg.setStrokeColor(species.outlineColor.cgColor)
        cg.setLineWidth(max(1.0, headR * 0.055))
        cg.addEllipse(in: headRect)
        cg.strokePath()

        // 4) 顶部高光（让球体有体积感）
        cg.saveGState()
        cg.addEllipse(in: headRect)
        cg.clip()
        let gloss = UIColor.white.withAlphaComponent(0.35).cgColor
        let clear = UIColor.white.withAlphaComponent(0).cgColor
        if let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [gloss, clear] as CFArray,
                               locations: [0, 1]) {
            cg.drawLinearGradient(g2,
                                  start: CGPoint(x: headRect.midX, y: headRect.minY),
                                  end: CGPoint(x: headRect.midX, y: headRect.midY + headR * 0.35),
                                  options: [])
        }
        cg.restoreGState()

        // 5) 五官
        drawFace(cg: cg, center: headCenter, radius: headR, species: species)
    }

    private static func drawEar(cg: CGContext, center: CGPoint, radius: CGFloat, angle: CGFloat, species: CatSpecies) {
        let rad = angle * .pi / 180
        let spread: CGFloat = 0.30          // 底边两点相对耳朵中轴的角度跨度
        let base = radius * 0.98
        let tipLength = radius * 1.42

        let p1 = CGPoint(x: center.x + cos(rad - spread) * base,
                         y: center.y - sin(rad - spread) * base)
        let p2 = CGPoint(x: center.x + cos(rad + spread) * base,
                         y: center.y - sin(rad + spread) * base)
        let tip = CGPoint(x: center.x + cos(rad) * tipLength,
                          y: center.y - sin(rad) * tipLength)

        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: tip)
        path.addLine(to: p2)
        path.close()

        cg.setFillColor(species.bottomColor.cgColor)
        cg.setStrokeColor(species.outlineColor.cgColor)
        cg.setLineWidth(max(1.0, radius * 0.05))
        path.fill()
        path.stroke()

        // 内耳
        let innerPath = UIBezierPath()
        innerPath.move(to: CGPoint(x: p1.x * 0.18 + tip.x * 0.82 + (p2.x - p1.x) * 0.16,
                                   y: p1.y * 0.18 + tip.y * 0.82 + (p2.y - p1.y) * 0.16))
        innerPath.addLine(to: CGPoint(x: tip.x, y: tip.y))
        innerPath.addLine(to: CGPoint(x: p2.x * 0.18 + tip.x * 0.82 - (p2.x - p1.x) * 0.16,
                                      y: p2.y * 0.18 + tip.y * 0.82 - (p2.y - p1.y) * 0.16))
        innerPath.close()
        cg.setFillColor(UIColor(hex: 0xFFB3C7).withAlphaComponent(0.75).cgColor)
        innerPath.fill()
    }

    private static func drawFace(cg: CGContext, center: CGPoint, radius: CGFloat, species: CatSpecies) {
        let cx = center.x
        let cy = center.y
        let isKing = species == .king
        let detail = radius > 18      // 小尺寸省略细节，避免糊成一团

        // 眼睛（大眼 + 高光，核心可爱来源）
        let eyeW = radius * 0.20
        let eyeH = radius * 0.30
        let eyeDX = radius * 0.38
        let eyeY = cy - radius * 0.02
        for dx in [-eyeDX, eyeDX] {
            let eyeRect = CGRect(x: cx + dx - eyeW / 2, y: eyeY - eyeH / 2, width: eyeW, height: eyeH)
            cg.setFillColor(UIColor(hex: 0x3B2B22).cgColor)
            cg.addEllipse(in: eyeRect)
            cg.fillPath()

            // 高光点
            let spark = CGRect(x: eyeRect.minX + eyeW * 0.22,
                               y: eyeRect.minY + eyeH * 0.18,
                               width: eyeW * 0.34,
                               height: eyeH * 0.24)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.addEllipse(in: spark)
            cg.fillPath()
        }

        // 腮红
        let blushW = radius * 0.26
        let blushH = radius * 0.16
        for dx in [-radius * 0.62, radius * 0.62] {
            let rect = CGRect(x: cx + dx - blushW / 2,
                              y: cy + radius * 0.24,
                              width: blushW,
                              height: blushH)
            cg.setFillColor(UIColor(hex: 0xFF8FA8).withAlphaComponent(0.42).cgColor)
            cg.addEllipse(in: rect)
            cg.fillPath()
        }

        // 鼻子
        let noseY = cy + radius * 0.34
        let noseSize = radius * 0.10
        cg.setFillColor(UIColor(hex: 0xE4758C).cgColor)
        cg.addEllipse(in: CGRect(x: cx - noseSize / 2, y: noseY, width: noseSize, height: noseSize * 0.8))
        cg.fillPath()

        // 嘴（ω 形）
        cg.setStrokeColor(UIColor(hex: 0x3B2B22).withAlphaComponent(0.85).cgColor)
        cg.setLineWidth(max(1.0, radius * 0.045))
        cg.setLineCap(.round)
        let mouthW = radius * 0.18
        for sign in [CGFloat(-1), CGFloat(1)] {
            cg.beginPath()
            cg.move(to: CGPoint(x: cx + sign * mouthW * 0.15, y: noseY + noseSize))
            cg.addQuadCurve(to: CGPoint(x: cx + sign * mouthW, y: noseY + noseSize * 0.5),
                            control: CGPoint(x: cx + sign * mouthW * 0.6, y: noseY + noseSize * 1.9))
            cg.strokePath()
        }

        guard detail else { return }

        // 胡须
        cg.setStrokeColor(UIColor(hex: 0x3B2B22).withAlphaComponent(0.35).cgColor)
        cg.setLineWidth(max(0.8, radius * 0.032))
        for sign in [CGFloat(-1), CGFloat(1)] {
            for i in 0..<2 {
                let offset = CGFloat(i) * radius * 0.14
                let start = CGPoint(x: cx + sign * radius * 0.34, y: cy + radius * 0.30 + offset)
                let end = CGPoint(x: cx + sign * radius * 1.05, y: cy + radius * 0.18 + offset * 1.6)
                cg.beginPath()
                cg.move(to: start)
                cg.addLine(to: end)
                cg.strokePath()
            }
        }

        // 猫王专属：小皇冠
        if isKing {
            let crownW = radius * 0.52
            let crownH = radius * 0.30
            let originX = cx - crownW / 2
            let originY = cy - radius * 1.02
            let path = UIBezierPath()
            path.move(to: CGPoint(x: originX, y: originY + crownH))
            path.addLine(to: CGPoint(x: originX + crownW * 0.18, y: originY))
            path.addLine(to: CGPoint(x: originX + crownW * 0.5, y: originY + crownH * 0.55))
            path.addLine(to: CGPoint(x: originX + crownW * 0.82, y: originY))
            path.addLine(to: CGPoint(x: originX + crownW, y: originY + crownH))
            path.close()
            cg.setFillColor(UIColor(hex: 0xFFD34D).cgColor)
            cg.setStrokeColor(UIColor(hex: 0xB8860B).withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(max(1.0, radius * 0.04))
            path.fill()
            path.stroke()
        }
    }
}
