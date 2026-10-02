import SwiftUI

/// 应用内「关于与合规信息」页。
///
/// 中国大陆上架的 App 需要在 App 内可访问的显著位置提供备案信息与隐私说明，
/// 因此这里集中展示：版本号、App 备案号、游戏出版物号、隐私立场、开源许可。
struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        CatChip(species: .king)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("合成猫 CatMerge")
                                .font(.headline)
                            Text("版本 \(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    complianceRow(title: "App 备案号", value: ComplianceInfo.appFilingNumber)
                    complianceRow(title: "网络游戏出版物号", value: ComplianceInfo.gamePublicationNumber)
                    complianceRow(title: "数据处理", value: "不收集任何数据，完全离线")
                } header: {
                    Text("合规信息")
                } footer: {
                    Text("在中国大陆上架前，请将占位文本替换为工信部实际备案结果与新闻出版署核发的出版物号。")
                }

                Section {
                    complianceRow(title: "音效", value: "数字合成，无外部素材")
                    complianceRow(title: "美术", value: "代码程序化绘制，无外部素材")
                } header: {
                    Text("素材来源")
                }

                Section {
                    Text("本项目以 MIT 许可发布。玩法参考 Asterless/MGPIC2025（Apache-2.0）与 LordSpecial/suika-game（Unlicense）；本工程为 Swift / SpriteKit 独立重写，未复制上游代码，也未使用上游任何图片或音频素材。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("开源许可")
                }
            }
            .navigationTitle("关于")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func complianceRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

/// 合规占位信息。上架前需替换为真实备案结果。
enum ComplianceInfo {
    /// 工信部 App 备案号（非经营性互联网信息服务备案）
    static let appFilingNumber = "未填写 · 上架前需补充工信部 App 备案号"
    /// 国家新闻出版署网络游戏出版物号（ISBN），中国大陆上架游戏必需
    static let gamePublicationNumber = "未填写 · 中国大陆上架游戏需取得版号"
}

#Preview {
    AboutView()
}
