# 开源小游戏 iOS 移植：选型结论 + 工程实现

> 目标：找一个**免费开源、玩法休闲、风格可爱、无需联网、足够有趣**的单机小游戏，原生移植到 iOS。
> 结论：移植「合成猫」——合成大西瓜（Suika-style merge）玩法的猫主题版本，SwiftUI + SpriteKit 原生实现。

---

## 一、选型结论

### 主推：合成猫（Cat Merge）

| 项目 | 说明 |
| --- | --- |
| 玩法原型 | 合成大西瓜（Suika Game）：从顶部掉落球体，同级相撞合成更高一级，堆过警戒线判负 |
| 上游参考 | ① `Asterless/MGPIC2025` 合成猫 Meme（**Apache-2.0**，MoonBit + Selene）<br>② `LordSpecial/suika-game`（**Unlicense / 公共领域**，matter.js，含 cats theme） |
| 许可证核实 | 两个仓库的 `LICENSE` 原文均已核对：Apache-2.0 全文、Unlicense 全文，可自由商用与二次分发 |
| 为什么是它 | ① 玩法经过全球验证，单局 1–3 分钟，休闲且上瘾；② 数值驱动，无需关卡美术；③ 猫 + 马卡龙配色天然可爱；④ 纯物理玩法 = 100% 离线；⑤ SpriteKit 原生支持，无需第三方引擎 |

### 备选（如想换题材）

| 候选 | 许可证 | 玩法 | 适配度 |
| --- | --- | --- | --- |
| `gabrielecirulli/2048` | MIT | 滑动合并数字 | 逻辑简单、实现快，但美术风格偏朴素，"可爱"分低 |
| `fonsecagabriella/tiny_cat` | 需自行核对 | 电子宠物养成（喂食 / 玩耍 / 休息 / 进化） | 极可爱、纯离线，但"有趣"依赖长期留存，单局爽感弱 |
| `SuperTux` | GPL-3.0 | 横版平台跳跃 | 体量大（数百 MB）、触屏手感一般、GPL 传染性对商业上架不友好 |

---

## 二、合规要点（上架前必读）

1. **玩法不受版权保护，素材受保护。**
   "掉落 + 同级合并"属于通用机制，可以自由实现；但原版 Suika Game 的**美术资源、名称、商标**受保护。因此本工程：
   - 不叫"合成大西瓜 / Suika"，命名为「合成猫 CatMerge」；
   - **不使用上游任何图片资源**，11 只猫全部由 `CatTextureFactory` 用 CoreGraphics 程序化绘制（耳朵 / 渐变球体 / 大眼高光 / 腮红 / 胡须 / 猫王皇冠）；
   - 音效由 `SoundManager` 数字合成（正弦 + 谐波 + ADSR 包络写入内存 WAV），不引入音频素材。
2. **Apache-2.0 致谢**：本工程为独立重写，未复制上游代码（语言与引擎完全不同）。仍建议在 App 内"关于"页注明玩法参考来源，避免争议。
3. **无网络**：工程不使用任何网络 API，Info.plist 无需 `NSAppTransportSecurity` 例外；隐私清单声明"不收集数据"。
4. **出口合规**：`Info.plist` 设置 `ITSAppUsesNonExemptEncryption = false`，绕过 ERN（加密出口登记）问询。

---

## 三、技术架构

```
SwiftUI（外壳：HUD / 结算 / 排行榜 / 设置）
        ↕  delegate + @Published
GameViewModel（@MainActor 状态桥接）
        ↕
SpriteKit（CatMergeScene：物理、碰撞、合并、特效）
        ↕
CatTextureFactory（程序化贴图） · SoundManager（合成音效） · HapticsManager（触觉）
        ↕
ScoreStore（UserDefaults 本地存档）
```

**为什么选 SpriteKit 而不是 Unity / 第三方框架**
- 系统内置，App 体积增量 ~0，无需引擎运行时；
- `SKPhysicsBody` 圆形碰撞 + `contactTestBitMask` 天然契合"同级合并"判定；
- 与 SwiftUI 通过 `SpriteView` 无缝组合，HUD 用 SwiftUI 写，自动获得 Dynamic Type / 深色模式 / VoiceOver 支持；
- 完全离线，无 SDK 依赖，隐私清单最简。

**物理参数映射（matter.js → SpriteKit）**

| 参数 | matter.js 参考 | 本工程 | 说明 |
| --- | --- | --- | --- |
| 重力 | y = 1（scale 0.001） | `gravity = -24 pt/s²` | SpriteKit 默认 -9.8 偏慢，-24 手感更弹 |
| 弹性 | restitution 0.1–0.3 | `0.10` | 略低，避免"果冻感" |
| 摩擦 | friction 0.3–0.5 | `0.42` | 保证堆叠稳定 |
| 密度 | 按半径递增 | 固定 `0.0018` | 大猫体积大自然更重，无需额外调参 |
| 时间步 | 16.67ms | 60fps，单帧 delta 上限 50ms | 卡顿保护，防止穿墙 |

---

## 四、目录结构

```
CatMerge/
├── README.md
├── project.yml                    xcodegen 工程描述（CI 用它生成 .xcodeproj）
├── Info.plist                     App 配置（已在根，无需 Xcode 模板）
├── .github/workflows/
│   ├── ios-build.yml              macOS runner 自动构建 iOS 产物
│   └── pages.yml                  部署 web/ 到 GitHub Pages
├── web/                           网页试玩版（纯前端、零依赖、离线可玩）
│   ├── index.html
│   └── game.js
├── Resources/
│   └── PrivacyInfo.xcprivacy
└── Sources/
    ├── App/
    │   └── CatMergeApp.swift          入口
    ├── Game/
    │   ├── CatSpecies.swift           11 级猫：名称 / 半径 / 配色 / 分值 / 掉落权重
    │   ├── GameConfig.swift           物理与判负参数（集中调优）
    │   ├── CatTextureFactory.swift    程序化绘制猫脸（SKTexture + UIImage 双输出）
    │   ├── CatNode.swift              猫节点（物理体 + 出生动画 + VoiceOver 标签）
    │   ├── CatMergeScene.swift        核心：掉落 / 碰撞 / 合并 / 特效 / 判负
    │   ├── SoundManager.swift         运行时合成音效（WAV → AVAudioPlayer）
    │   └── HapticsManager.swift       触觉反馈分级
    ├── Data/
    │   └── ScoreStore.swift           本机最高分与历史记录
    └── UI/
        ├── GameViewModel.swift        SwiftUI ↔ SKScene 桥接
        └── GameView.swift             HUD / 竞技场 / 结算卡 / 排行榜
```

---

## 五、数值配置

| 等级 | 名称 | 半径(pt) | 合成得分 | 掉落权重 |
| --- | --- | --- | --- | --- |
| 0 | 奶猫崽 | 13 | 1 | 34% |
| 1 | 棉花糖 | 17.5 | 3 | 27% |
| 2 | 布丁 | 23 | 6 | 20% |
| 3 | 橘子 | 29.5 | 10 | 12% |
| 4 | 狸花 | 37 | 15 | 7% |
| 5 | 奶牛 | 45.5 | 21 | — |
| 6 | 三花 | 55 | 28 | — |
| 7 | 蓝胖子 | 65.5 | 36 | — |
| 8 | 布偶 | 77 | 45 | — |
| 9 | 缅因 | 89 | 55 | — |
| 10 | 猫王 | 102 | 120 | —（两只猫王相撞 +300 并双双消失） |

其他：掉落冷却 0.42s；新猫宽限 1.0s；越警戒线持续 1.6s 判负；警戒线距顶 138pt。

---

## 六、HIG 与无障碍清单（已实现）

- **导航**：无 hamburger 菜单，单屏 + 3 个工具栏按钮（暂停 / 音效 / 排行榜）；排行榜为 Modal，提供"关闭"按钮与下滑关闭。
- **触控目标**：所有按钮 `minWidth/minHeight = 44pt`，并加 `contentShape(Rectangle())` 扩大热区。
- **安全区**：交互元素均在安全区内，`.ignoresSafeArea()` 只用于背景渐变与遮罩。
- **不靠颜色单独传达信息**：等级同时由**尺寸 + 名称文字 + VoiceOver 标签**区分，配色只是增强。
- **VoiceOver**：分数、最高分、下一只猫、按钮均有 `accessibilityLabel`；合成与结束通过 `.announcement` 播报。
- **Dynamic Type**：间距用 `@ScaledMetric`，文字全部使用语义化字体 `.caption2/.footnote/.subheadline/.title`，最大字号不裁切。
- **减弱动态效果**：`UIAccessibility.isReduceMotionEnabled` 为真时关闭粒子、呼吸动画与弹性缩放（保留必要反馈）。
- **触觉分级**：掉落用 selection，合成按等级 light→medium→heavy，猫王为 `.success`，失败为 `.warning`。
- **深色模式**：背景渐变与阴影强度随 `colorScheme` 切换，猫贴图为自绘不透明色，深浅模式均清晰。
- **生命周期**：`touchesCancelled` 不触发掉落（来电 / 控制中心等中断不误操作）；暂停时 `scene.isPaused` 生效。

---

## 七、Xcode 接入步骤

1. 新建 iOS App（Swift / SwiftUI），**Deployment Target: iOS 17.0**，设备 iPhone，取消 Core Data / Tests 之外的多余选项。
2. 把 `Sources/` 与 `Resources/` 拖入工程，勾选 "Copy items if needed" 与 target membership。
3. `CatMergeApp.swift` 设为 `@main`（删除模板自带的 `App` 结构体）。
4. Info.plist 补充：
   ```xml
   <key>ITSAppUsesNonExemptEncryption</key><false/>
   <key>UIRequiresFullScreen</key><true/>
   <key>UISupportedInterfaceOrientations</key>
   <array><string>UIInterfaceOrientationPortrait</string></array>
   ```
5. 真机运行（模拟器无触觉，功能不受影响）。

---

## 八、App Store 上架 Checklist

- [ ] 隐私详情：选择"不收集数据"，上传 `PrivacyInfo.xcprivacy`
- [ ] 年龄分级：4+（无暴力、无 UGC、无广告、无 Web 访问）
- [ ] 名称与副标题避免含 "Suika / 大西瓜" 等商标词，建议「合成猫：休闲合并小游戏」
- [ ] 截图：6.9" / 6.5" 竖屏各一组，覆盖浅色与深色
- [ ] 描述中明确：**完全离线、无广告、无内购、无账号**
- [ ] App 内"关于"页：注明玩法参考来源与许可证（Apache-2.0 / Unlicense）
- [ ] 无网络请求 → 无需提供账号删除功能；无需隐私政策之外的合规项（仍建议准备一份简短隐私政策链接）

---

## 九、后续迭代路线

| 版本 | 内容 | 备注 |
| --- | --- | --- |
| v1.1 | 皮肤包（狗 / 熊猫 / 水果） | 复用 `CatSpecies` 协议化即可 |
| v1.2 | 撤销一步 / 抖动重排（有限次数） | 提升容错，降低挫败感 |
| v1.3 | Game Center 排行榜 | **会引入联网**，需重新评估"纯离线"卖点，建议做成可关闭开关 |
| v1.4 | 每日挑战 + WidgetKit 桌面组件 | 离线可实现（用日期做种子） |
| v1.5 | iPad 横屏 + 指针 / 键盘支持 | arena 宽度上限放开，物理参数不变 |

---

## 十、在线试玩（无需安装）

仓库已内置网页试玩版 `web/`，推送后由 GitHub Pages 自动部署：

```
https://lcyxyq.github.io/CatMerge/
```

- 手机 / 电脑浏览器直接打开即可玩，玩法、数值、猫脸绘制与 iOS 版一致；
- 纯前端零依赖，首次加载后完全离线（成绩存在浏览器 localStorage）；
- 手机 Safari 可用「分享 → 添加到主屏幕」当 App 用；
- 本地预览：直接双击 `web/index.html`，或在仓库根目录起一个静态服务：

```bash
python3 -m http.server 8000 --directory web
```

## 十一、GitHub Actions 自动构建

`.github/workflows/ios-build.yml` 在每次 push 到 main 时触发（也可手动 dispatch）：

1. macOS runner 上 `brew install xcodegen`；
2. `xcodegen generate` 由 `project.yml` 生成 `CatMerge.xcodeproj`（仓库不提交二进制工程文件）；
3. `xcodebuild` 构建 iOS Simulator 版，打包为 `CatMerge-iOS-Simulator.zip`；
4. 额外尝试构建未签名设备版并打包 `CatMerge-unsigned.ipa`；
5. 两者都作为 Artifact 上传，保留 30 天。

**下载方式**：仓库 → Actions → 最新的 `iOS Build` → 页面底部 Artifacts。

## 十二、怎么装到 iPhone（重要）

iOS 的安装受签名限制，这里说清楚可行路径：

| 方式 | 条件 | 说明 |
| --- | --- | --- |
| Xcode 真机运行（推荐） | 有 Mac + 免费 Apple ID | `git clone` → `xcodegen generate` → `open CatMerge.xcodeproj` → 选自己的设备 → 自动管理签名。免费账号签名有效期 **7 天**，到期重跑一次即可 |
| TestFlight / App Store | Apple Developer Program（约 ¥688/年） | 唯一能正常分发给他人安装的方式 |
| 未签名 IPA | 越狱设备 | CI 产出的 `CatMerge-unsigned.ipa` 仅供自签或越狱环境使用 |
| 网页试玩版 | 任何浏览器 | 免安装，最快体验玩法 |

> 注意：GitHub Actions 的 macOS runner 只负责**构建**，不能替你签名安装——Apple 签名必须绑定你自己的 Apple ID / 开发者账号。

## 十三、开源许可

- 本工程代码：**MIT**（见 `LICENSE`）。
- 玩法参考来源：`Asterless/MGPIC2025`（Apache-2.0）与 `LordSpecial/suika-game`（Unlicense）。
- 所有猫脸图形与音效均为本工程程序化生成，不含任何上游素材。
