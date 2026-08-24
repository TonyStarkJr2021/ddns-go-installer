#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# DDNS-GO Universal Installer
# Version: 1.0.0
#
# Repository:
# https://github.com/TonyStarkJr2021/ddns-go-installer
#
# Upstream:
# https://github.com/jeessy2/ddns-go
# ============================================================

APP_VERSION="1.0.0"

UPSTREAM_REPO="jeessy2/ddns-go"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="${INSTALL_DIR}/ddns-go"

DEFAULT_WEB_PORT="9876"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'


info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}


cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}

trap cleanup EXIT
trap 'error "安装失败，出错行：${LINENO}"' ERR


# ============================================================
# Root check
# ============================================================

if [[ "$(id -u)" -ne 0 ]]; then
    error "请使用 root 用户执行此安装脚本。"
    exit 1
fi


echo
echo "============================================================"
echo " DDNS-GO Universal Installer v${APP_VERSION}"
echo "============================================================"
echo


# ============================================================
# OS detection
# ============================================================

OS_ID="unknown"
OS_NAME="Linux"

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
fi

success "Linux: ${OS_NAME}"


# ============================================================
# systemd check
# ============================================================

if ! command -v systemctl >/dev/null 2>&1; then
    error "当前系统没有检测到 systemd/systemctl。"
    error "本安装器 V1 暂时仅支持 systemd Linux。"
    exit 1
fi

if [[ ! -d /run/systemd/system ]]; then
    error "systemd 当前未作为 init 系统运行。"
    exit 1
fi

success "Init system: systemd"


# ============================================================
# Dependency installation
# ============================================================

install_dependencies() {

    local need_curl=0
    local need_tar=0
    local need_ca=0

    command -v curl >/dev/null 2>&1 || need_curl=1
    command -v tar >/dev/null 2>&1 || need_tar=1

    if [[ ! -d /etc/ssl/certs ]]; then
        need_ca=1
    fi

    if (( need_curl == 0 && need_tar == 0 && need_ca == 0 )); then
        success "依赖已满足。"
        return
    fi


    if command -v apt-get >/dev/null 2>&1; then

        info "包管理器：apt"

        apt-get update

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            $([[ "$need_curl" == "1" ]] && echo curl) \
            $([[ "$need_tar" == "1" ]] && echo tar) \
            $([[ "$need_ca" == "1" ]] && echo ca-certificates)


    elif command -v dnf >/dev/null 2>&1; then

        info "包管理器：dnf"

        dnf install -y \
            $([[ "$need_curl" == "1" ]] && echo curl) \
            $([[ "$need_tar" == "1" ]] && echo tar) \
            $([[ "$need_ca" == "1" ]] && echo ca-certificates)


    elif command -v yum >/dev/null 2>&1; then

        info "包管理器：yum"

        yum install -y \
            $([[ "$need_curl" == "1" ]] && echo curl) \
            $([[ "$need_tar" == "1" ]] && echo tar) \
            $([[ "$need_ca" == "1" ]] && echo ca-certificates)


    elif command -v pacman >/dev/null 2>&1; then

        info "包管理器：pacman"

        pacman -Sy --noconfirm \
            $([[ "$need_curl" == "1" ]] && echo curl) \
            $([[ "$need_tar" == "1" ]] && echo tar) \
            $([[ "$need_ca" == "1" ]] && echo ca-certificates)


    elif command -v zypper >/dev/null 2>&1; then

        info "包管理器：zypper"

        zypper --non-interactive install \
            $([[ "$need_curl" == "1" ]] && echo curl) \
            $([[ "$need_tar" == "1" ]] && echo tar) \
            $([[ "$need_ca" == "1" ]] && echo ca-certificates)


    else

        error "无法识别受支持的包管理器。"
        error "当前支持：apt / dnf / yum / pacman / zypper"
        exit 1

    fi
}

install_dependencies

success "依赖检查完成。"


# ============================================================
# Architecture detection
# ============================================================

CPU_ARCH="$(uname -m)"

case "${CPU_ARCH}" in

    x86_64|amd64)
        DDNS_ARCH="x86_64"
        ;;

    i386|i486|i586|i686)
        DDNS_ARCH="i386"
        ;;

    aarch64|arm64)
        DDNS_ARCH="arm64"
        ;;

    armv7l|armv7)
        DDNS_ARCH="armv7"
        ;;

    armv6l|armv6)
        DDNS_ARCH="armv6"
        ;;

    armv5l|armv5)
        DDNS_ARCH="armv5"
        ;;

    riscv64)
        DDNS_ARCH="riscv64"
        ;;

    *)
        error "暂不支持的 CPU 架构：${CPU_ARCH}"
        exit 1
        ;;

esac

success "CPU 架构：${CPU_ARCH} → ${DDNS_ARCH}"


# ============================================================
# Existing installation detection
# ============================================================

if [[ -x "${INSTALL_PATH}" ]]; then

    CURRENT_VERSION="$(
        "${INSTALL_PATH}" -v 2>/dev/null \
        | head -n1 \
        || true
    )"

    warn "检测到 DDNS-GO 已安装："
    echo "  ${INSTALL_PATH}"

    if [[ -n "${CURRENT_VERSION}" ]]; then
        echo "  ${CURRENT_VERSION}"
    fi

    echo
    read -rp "是否继续重新安装？[y/N]: " REINSTALL

    if [[ ! "${REINSTALL}" =~ ^[Yy]$ ]]; then
        echo
        info "已取消安装。"
        echo "如需升级，请使用后续提供的 update.sh。"
        exit 0
    fi
fi


# ============================================================
# Get latest release
# ============================================================

info "获取 DDNS-GO 最新版本..."

LATEST_TAG="$(
    curl -fsSL \
        --connect-timeout 10 \
        --max-time 30 \
        "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" \
    | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -n1 \
    | cut -d '"' -f4
)"


if [[ -z "${LATEST_TAG}" ]]; then
    error "无法获取 DDNS-GO 最新 Release。"
    exit 1
fi

LATEST_VERSION="${LATEST_TAG#v}"

success "最新版本：${LATEST_TAG}"


# ============================================================
# Download URL
# ============================================================

ARCHIVE_NAME="ddns-go_${LATEST_VERSION}_linux_${DDNS_ARCH}.tar.gz"

DOWNLOAD_URL="https://github.com/${UPSTREAM_REPO}/releases/download/${LATEST_TAG}/${ARCHIVE_NAME}"

echo
info "下载文件：${ARCHIVE_NAME}"


# ============================================================
# Temporary directory
# ============================================================

TMP_DIR="$(mktemp -d)"

ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"


# ============================================================
# Download
# ============================================================

curl -fL \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    --max-time 300 \
    "${DOWNLOAD_URL}" \
    -o "${ARCHIVE_PATH}"


if [[ ! -s "${ARCHIVE_PATH}" ]]; then
    error "下载文件为空。"
    exit 1
fi

success "下载完成。"


# ============================================================
# Extract
# ============================================================

info "解压 DDNS-GO..."

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"


DDNS_BINARY="$(
    find "${TMP_DIR}" \
        -type f \
        -name "ddns-go" \
        -perm -u+x \
        | head -n1 \
        || true
)"


if [[ -z "${DDNS_BINARY}" ]]; then

    DDNS_BINARY="$(
        find "${TMP_DIR}" \
            -type f \
            -name "ddns-go" \
            | head -n1 \
            || true
    )"

fi


if [[ -z "${DDNS_BINARY}" || ! -f "${DDNS_BINARY}" ]]; then
    error "解压后没有找到 ddns-go 二进制文件。"
    exit 1
fi


chmod +x "${DDNS_BINARY}"


# ============================================================
# Binary test
# ============================================================

info "验证 DDNS-GO 二进制..."

if ! "${DDNS_BINARY}" -v >/dev/null 2>&1; then

    if ! "${DDNS_BINARY}" --help >/dev/null 2>&1; then
        error "DDNS-GO 二进制无法正常运行。"
        exit 1
    fi

fi

success "二进制验证通过。"


# ============================================================
# Stop existing DDNS-GO service if present
# ============================================================

if systemctl list-unit-files --type=service --no-legend 2>/dev/null \
    | awk '{print $1}' \
    | grep -qi '^ddns-go\.service$'; then

    info "停止已有 ddns-go.service..."

    systemctl stop ddns-go.service 2>/dev/null || true

fi


# ============================================================
# Install binary
# ============================================================

mkdir -p "${INSTALL_DIR}"

install \
    -m 755 \
    "${DDNS_BINARY}" \
    "${INSTALL_PATH}"

success "程序安装到：${INSTALL_PATH}"


# ============================================================
# Service install
# ============================================================

info "安装 DDNS-GO 系统服务..."

"${INSTALL_PATH}" -s uninstall >/dev/null 2>&1 || true

"${INSTALL_PATH}" -s install


sleep 2


# ============================================================
# Service detection
# ============================================================

DDNS_SERVICE="$(
    systemctl list-unit-files \
        --type=service \
        --no-legend 2>/dev/null \
    | awk '{print $1}' \
    | grep -i '^ddns-go.*\.service$' \
    | head -n1 \
    || true
)"


if [[ -z "${DDNS_SERVICE}" ]]; then

    DDNS_SERVICE="$(
        systemctl list-units \
            --all \
            --type=service \
            --no-legend 2>/dev/null \
        | awk '{print $1}' \
        | grep -i '^ddns-go.*\.service$' \
        | head -n1 \
        || true
    )"

fi


if [[ -z "${DDNS_SERVICE}" ]]; then
    error "DDNS-GO 服务安装后未能找到 systemd service。"
    exit 1
fi


systemctl daemon-reload

systemctl enable "${DDNS_SERVICE}" >/dev/null 2>&1 || true

systemctl restart "${DDNS_SERVICE}"


sleep 2


if ! systemctl is-active --quiet "${DDNS_SERVICE}"; then

    error "DDNS-GO 服务启动失败。"

    echo
    echo "请执行："
    echo
    echo "journalctl -u ${DDNS_SERVICE} -n 100 --no-pager"

    exit 1
fi


success "系统服务：${DDNS_SERVICE}"
success "运行状态：active"


# ============================================================
# Detect listen port
# ============================================================

DETECTED_PORT=""

MAIN_PID="$(
    systemctl show \
        "${DDNS_SERVICE}" \
        -p MainPID \
        --value 2>/dev/null \
        || true
)"


if command -v ss >/dev/null 2>&1 \
    && [[ "${MAIN_PID}" =~ ^[0-9]+$ ]] \
    && [[ "${MAIN_PID}" != "0" ]]; then

    DETECTED_PORT="$(
        ss -lntp 2>/dev/null \
        | grep "pid=${MAIN_PID}," \
        | awk '{print $4}' \
        | sed -E 's/.*:([0-9]+)$/\1/' \
        | head -n1 \
        || true
    )"

fi


if [[ -z "${DETECTED_PORT}" ]]; then
    DETECTED_PORT="${DEFAULT_WEB_PORT}"
fi


# ============================================================
# Installed version
# ============================================================

INSTALLED_VERSION="$(
    "${INSTALL_PATH}" -v 2>/dev/null \
    | head -n1 \
    || true
)"


# ============================================================
# Final output
# ============================================================

echo
echo "============================================================"
echo " DDNS-GO 安装完成"
echo "============================================================"
echo
echo "系统：${OS_NAME}"
echo "架构：${CPU_ARCH}"
echo "版本：${LATEST_TAG}"
echo "程序：${INSTALL_PATH}"
echo "服务：${DDNS_SERVICE}"
echo "Web端口：${DETECTED_PORT}"
echo

if [[ -n "${INSTALLED_VERSION}" ]]; then
    echo "程序版本信息：${INSTALLED_VERSION}"
    echo
fi

echo "首次配置："
echo "  http://服务器IP:${DETECTED_PORT}"
echo

echo "如果已经配置域名和端口映射，也可以访问："
echo "  http://你的域名:${DETECTED_PORT}"
echo

echo "查看服务："
echo "  systemctl status ${DDNS_SERVICE}"
echo

echo "查看日志："
echo "  journalctl -u ${DDNS_SERVICE} -n 100 --no-pager"
echo

echo "============================================================"

success "DDNS-GO 安装成功。"
