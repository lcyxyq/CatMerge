#!/usr/bin/env bash
# 在 WSL2 (Ubuntu) 里安装 xtool 及其依赖，用于把「合成猫」构建并部署到真机。
#
# 用法（在 WSL 的 Ubuntu 终端里执行）：
#   git clone https://github.com/lcyxyq/CatMerge.git
#   cd CatMerge
#   bash scripts/setup-xtool-wsl.sh
#
# 脚本只负责"能自动化的部分"。以下三步必须你手动完成（涉及 Apple 账号与交互）：
#   1. 从 https://developer.apple.com/download/all/?q=Xcode 下载 Xcode.xip（需 Apple ID 登录）
#   2. 运行 xtool setup，按提示登录 Apple ID（密码模式支持免费 Apple ID）
#   3. USB 连接 iPhone，在 Windows 端用 usbipd 把设备绑定到 WSL
set -euo pipefail

SWIFT_VERSION="${SWIFT_VERSION:-6.3}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/swift}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f /etc/os-release ]] || die "本脚本需要在 WSL 的 Ubuntu/Debian 中运行"
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]] || warn "未测试的发行版: ${ID:-unknown}"

# ---------------------------------------------------------------- 1. 系统依赖
info "安装系统依赖（usbmuxd / libimobiledevice / 解压工具）"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  usbmuxd libimobiledevice-utils libplist-utils \
  curl unzip xz-utils zstd binutils fuse libfuse2 \
  libxml2-dev libcurl4-openssl-dev libssl-dev

# ---------------------------------------------------------------- 2. Swift
if command -v swift >/dev/null 2>&1; then
  info "已检测到 Swift: $(swift --version | head -1)"
else
  UBUNTU_VERSION="${VERSION_ID:-22.04}"
  UBUNTU_SHORT="${UBUNTU_VERSION//./}"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) SWIFT_ARCH_SUFFIX="" ;;
    aarch64) SWIFT_ARCH_SUFFIX="-aarch64" ;;
    *) die "不支持的架构: $ARCH" ;;
  esac
  TARBALL="swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_VERSION}${SWIFT_ARCH_SUFFIX}.tar.gz"
  URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu${UBUNTU_SHORT}/swift-${SWIFT_VERSION}-RELEASE/${TARBALL}"

  info "探测 Swift 下载地址: $URL"
  if ! curl -fsI "$URL" >/dev/null 2>&1; then
    warn "自动构造的下载地址不可用（版本号可能已变化）。"
    warn "请手动从 https://swift.org/install/linux/ 下载 Swift ${SWIFT_VERSION} 的 tar.gz，"
    warn "然后把它解压到 ${INSTALL_PREFIX}，并把 ${INSTALL_PREFIX}/usr/bin 加入 PATH 后重跑本脚本。"
    exit 1
  fi

  info "下载 Swift ${SWIFT_VERSION}（约 700MB，请耐心等待）"
  curl -fL --progress-bar "$URL" -o "/tmp/${TARBALL}"

  info "解压到 ${INSTALL_PREFIX}"
  sudo mkdir -p "$INSTALL_PREFIX"
  sudo tar -xzf "/tmp/${TARBALL}" -C "$INSTALL_PREFIX" --strip-components=1
  rm -f "/tmp/${TARBALL}"

  SHELL_RC="$HOME/.bashrc"
  if ! grep -q "usr/bin\"\$PATH" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"${INSTALL_PREFIX}/usr/bin:\$PATH\"" >> "$SHELL_RC"
  fi
  export PATH="${INSTALL_PREFIX}/usr/bin:${PATH}"
  info "Swift 安装完成: $(swift --version | head -1)"
fi

# ---------------------------------------------------------------- 3. xtool
if command -v xtool >/dev/null 2>&1; then
  info "已检测到 xtool: $(xtool --version 2>/dev/null || echo '已安装')"
else
  ARCH="$(uname -m)"
  info "下载 xtool AppImage (${ARCH})"
  curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-${ARCH}.AppImage" \
    -o "$HOME/xtool"
  chmod +x "$HOME/xtool"
  sudo mv "$HOME/xtool" /usr/local/bin/xtool

  if ! xtool --help >/dev/null 2>&1; then
    warn "AppImage 无法直接运行（多半是 WSL 缺少 FUSE 支持）。"
    warn "解决办法：在 /etc/wsl.conf 中加入 [boot] systemd=true 与 [wsl2] kernelCommandLine=... ，"
    warn "或改用解包模式："
    warn "  cd /tmp && /usr/local/bin/xtool --appimage-extract && sudo mv squashfs-root /opt/xtool && sudo ln -sf /opt/xtool/AppRun /usr/local/bin/xtool"
  fi
  info "xtool 安装完成"
fi

# ---------------------------------------------------------------- 4. 后续步骤
cat <<'NEXT'

------------------------------------------------------------------
xtool 已就绪。接下来这三步需要你手动完成（涉及 Apple 账号与交互）：

  1) 下载 Xcode.xip
     打开 https://developer.apple.com/download/all/?q=Xcode
     用你的 Apple ID 登录，下载最新的 Xcode.xip（约 10GB+，解压后需约 60GB 空间）。
     记住保存路径，例如 /home/你的用户名/Downloads/Xcode_26.xip
     提示：放在 WSL 的 ext4 文件系统里（~/ 下），不要放在 /mnt/c 下，解压会快很多。

  2) 登录并生成 iOS SDK
     xtool setup
     - 登录方式选 1（Password，支持免费 Apple ID）或 0（API Key，需付费开发者账号）
     - 按提示输入邮箱、密码、2FA 验证码
     - 然后输入第 1 步的 Xcode.xip 路径，xtool 会生成名为 darwin 的 Swift SDK
     验证：swift sdk list   # 应该显示 darwin

  3) 连接 iPhone 并部署
     Windows 端（管理员 PowerShell）：
       winget install usbipd
       usbipd list                       # 找到 iPhone 的 BUSID
       usbipd bind --busid <BUSID>
       usbipd attach --wsl --busid <BUSID>
     WSL 端：
       ideviceinfo                       # 能输出设备信息说明连接成功
       cd CatMerge && xtool dev          # 构建 + 签名 + 安装到手机
     首次会要求：手机上点「信任」、输入锁屏密码、并在 设置 → 隐私与安全性 里开启「开发者模式」；
     若报错，按提示处理后再跑一次 xtool dev。

------------------------------------------------------------------
NEXT
