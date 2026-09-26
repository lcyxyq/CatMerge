import SpriteKit
import SwiftUI

struct GameView: View {

    @StateObject private var viewModel = GameViewModel()
    @AppStorage("catmerge.sound") private var soundEnabled = true
    @AppStorage("catmerge.haptics") private var hapticsEnabled = true

    @State private var showScoreboard = false
    @State private var isResultCardDismissed = false
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: spacing) {
                hud
                arena
                footer
            }
            .padding(spacing)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(background.ignoresSafeArea())
        .overlay {
            if viewModel.isGameOver && !isResultCardDismissed {
                resultCard
            }
        }
        .sheet(isPresented: $showScoreboard) {
            ScoreboardView()
        }
        .onAppear(perform: applySettings)
        .onChange(of: soundEnabled) { _ in applySettings() }
        .onChange(of: hapticsEnabled) { _ in applySettings() }
    }

    // MARK: - 顶部信息栏

    private var hud: some View {
        HStack(alignment: .center, spacing: spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text("得分")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.score)")
                    .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                    .accessibilityLabel("当前得分 \(viewModel.score)")
                Text("最高 \(viewModel.bestScore)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("历史最高 \(viewModel.bestScore)")
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                CatChip(species: viewModel.nextSpecies)
                VStack(alignment: .leading, spacing: 2) {
                    Text("下一只")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(viewModel.nextSpecies.displayName)
                        .font(.subheadline.weight(.medium))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("下一只猫：\(viewModel.nextSpecies.displayName)")
            .accessibilityAddTraits(.updatesFrequently)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                toolbarButton(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill",
                              label: viewModel.isPaused ? "继续" : "暂停") {
                    viewModel.togglePause()
                }
                toolbarButton(systemName: soundEnabled ? "speaker.wave.2.circle.fill" : "speaker.slash.circle.fill",
                              label: soundEnabled ? "关闭音效" : "开启音效") {
                    soundEnabled.toggle()
                }
                toolbarButton(systemName: "trophy.circle.fill", label: "排行榜") {
                    showScoreboard = true
                }
            }
        }
    }

    private func toolbarButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(minWidth: 44, minHeight: 44)     // HIG：44pt 最小触控目标
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - 游戏区

    private var arena: some View {
        SpriteView(scene: viewModel.scene, transition: nil, isPaused: false)
            .frame(maxWidth: 420)
            .aspectRatio(0.62, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, y: 8)
            .accessibilityElement()
            .accessibilityLabel("游戏区")
            .accessibilityHint("左右拖动选择位置，松开手指放下猫咪")
    }

    private var footer: some View {
        Text("拖动瞄准 · 松手放下 · 两只相同的猫会合成更大的猫")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 结算卡片

    private var resultCard: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("游戏结束")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button {
                        isResultCardDismissed = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭结算卡片")
                }

                VStack(spacing: 4) {
                    Text("本局得分")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.score)")
                        .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                        .accessibilityLabel("本局得分 \(viewModel.score)")
                }

                if viewModel.isNewBest {
                    Text("新纪录！")
                        .font(.headline)
                        .foregroundStyle(.pink)
                        .accessibilityLabel("刷新历史最高分")
                }

                Text("最大猫咪：\(viewModel.topSpecies.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        isResultCardDismissed = false
                        viewModel.restart()
                    } label: {
                        Text("再来一局")
                            .font(.headline)
                            .frame(minWidth: 120, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .accessibilityHint("清空场地并重新开始")

                    Button {
                        showScoreboard = true
                    } label: {
                        Text("排行榜")
                            .font(.headline)
                            .frame(minWidth: 96, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(28)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isGameOver)
    }

    // MARK: - 外观

    private var background: some View {
        let top = Color(uiColor: UIColor(hex: colorScheme == .dark ? 0x1C1A20 : 0xFFF7F1))
        let bottom = Color(uiColor: UIColor(hex: colorScheme == .dark ? 0x2A2430 : 0xFFE6EF))
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private func applySettings() {
        SoundManager.shared.isEnabled = soundEnabled
        HapticsManager.isEnabled = hapticsEnabled
    }
}

// MARK: - 猫咪小头像

struct CatChip: View {
    let species: CatSpecies

    var body: some View {
        Image(uiImage: CatTextureFactory.image(for: species))
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .accessibilityLabel(species.displayName)
    }
}

// MARK: - 本地排行榜

struct ScoreboardView: View {
    @ObservedObject private var store = ScoreStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView("还没有记录",
                                           systemImage: "trophy",
                                           description: Text("玩一局，成绩会自动保存在本机"))
                } else {
                    List {
                        Section {
                            ForEach(store.records) { record in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(record.score) 分")
                                            .font(.headline.monospacedDigit())
                                        Text("最大猫咪：\(record.topSpecies)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(record.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 44)
                            }
                        } header: {
                            Text("历史最高 \(store.bestScore) 分")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("排行榜")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("清空") { store.clearAll() }
                        .disabled(store.records.isEmpty)
                }
            }
        }
    }
}

#Preview {
    GameView()
}
