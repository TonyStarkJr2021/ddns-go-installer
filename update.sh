#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# DDNS-GO Universal Updater
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

DEFAULT_INSTALL_PATH="/usr/local/bin/ddns-go"
BACKUP_DIR="/usr/local/share/ddns-go-installer/backups"

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
trap 'error "更新失败，出错行：${LINENO}"' ERR


# ============================================================
# Root check
# ============================================================

if [[ "$(id -u)" -ne 0 ]]; then
    error "请使用 root 用户执行此更新脚本。"
    exit 1
fi


echo
echo "============================================================"
echo " DDNS-GO Universal Updater v${APP_VERSION}"
echo "============================================================"
echo


# ============================================================
# systemd check
# ============================================================

if ! command -v systemctl >/dev/null 2>&1; then
    error "当前系统没有检测到 systemd/systemctl。"
    exit 1
fi


# ============================================================
# Dependency check
# ============================================================

if ! command -v curl >/dev/null 2>&1; then
    error "缺少 curl，请先安装 curl。"
    exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
    error "缺少 tar，请先安装 tar。"
    exit 1
fi


# ============================================================
# Detect DDNS-GO binary
# ============================================================

detect_ddns_binary() {

    local candidates=(
        "/usr/local/bin/ddns-go"
        "/usr/bin/ddns-go"
        "/opt/ddns-go/ddns-go"
    )

    local item

    for item in "${candidates[@]}"; do

        if [[ -x "${item}" ]]; then
            echo "${item}"
            return 0
        fi

    done


    if command -v ddns-go >/dev/null 2>&1; then
        command -v ddns-go
        return 0
    fi


    return 1
}


info "检测 DDNS-GO 安装位置..."

if INSTALL_PATH="$(detect_ddns_binary)"; then
    success "程序：${INSTALL_PATH}"
else
    error "没有检测到已安装的 DDNS-GO。"
    echo
    echo "请先执行 install.sh 安装。"
    exit 1
fi


# ============================================================
# Detect service
# ============================================================

detect_service() {

    local service

    service="$(
        systemctl list-unit-files \
            --type=service \
            --no-legend 2>/dev/null \
        | awk '{print $1}' \
        | grep -Ei '^ddns-go.*\.service$' \
        | head -n1 \
        || true
    )"

    if [[ -n "${service}" ]]; then
        echo "${service}"
        return 0
    fi


    service="$(
        systemctl list-units \
            --all \
            --type=service \
            --no-legend 2>/dev/null \
        | awk '{print $1}' \
        | grep -Ei '^ddns-go.*\.service$' \
        | head -n1 \
        || true
    )"

    if [[ -n "${service}" ]]; then
        echo "${service}"
        return 0
    fi


    return 1
}


info "检测 DDNS-GO systemd 服务..."

if DDNS_SERVICE="$(detect_service)"; then
    success "服务：${DDNS_SERVICE}"
else
    error "未找到 DDNS-GO systemd 服务。"
    exit 1
fi


# ============================================================
# Get current version
# ============================================================

CURRENT_VERSION_RAW="$(
    "${INSTALL_PATH}" -v 2>/dev/null \
    | head -n1 \
    || true
)"


CURRENT_VERSION="$(
    printf '%s\n' "${CURRENT_VERSION_RAW}" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    || true
)"


if [[ -z "${CURRENT_VERSION}" ]]; then
    warn "无法准确识别当前版本。"
    CURRENT_VERSION="unknown"
else
    success "当前版本：v${CURRENT_VERSION}"
fi


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
# Get latest release
# ============================================================

info "查询 DDNS-GO 最新版本..."

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
# Version comparison
# ============================================================

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then

    echo
    success "当前已经是最新版 ${LATEST_TAG}，无需更新。"
    echo

    exit 0

fi


echo
echo "------------------------------------------------------------"
echo "准备更新"
echo "------------------------------------------------------------"
echo "当前版本：v${CURRENT_VERSION}"
echo "最新版本：${LATEST_TAG}"
echo "程序位置：${INSTALL_PATH}"
echo "系统服务：${DDNS_SERVICE}"
echo "------------------------------------------------------------"
echo


read -rp "确认更新 DDNS-GO？[Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    info "已取消更新。"
    exit 0
fi


# ============================================================
# Download new version
# ============================================================

ARCHIVE_NAME="ddns-go_${LATEST_VERSION}_linux_${DDNS_ARCH}.tar.gz"

DOWNLOAD_URL="https://github.com/${UPSTREAM_REPO}/releases/download/${LATEST_TAG}/${ARCHIVE_NAME}"


TMP_DIR="$(mktemp -d)"

ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"


echo
info "下载：${ARCHIVE_NAME}"


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

info "解压新版本..."

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"


NEW_BINARY="$(
    find "${TMP_DIR}" \
        -type f \
        -name "ddns-go" \
        | head -n1 \
        || true
)"


if [[ -z "${NEW_BINARY}" || ! -f "${NEW_BINARY}" ]]; then
    error "解压后没有找到 ddns-go 二进制文件。"
    exit 1
fi


chmod +x "${NEW_BINARY}"


# ============================================================
# Verify new binary
# ============================================================

info "验证新版本二进制..."

NEW_VERSION_RAW="$(
    "${NEW_BINARY}" -v 2>/dev/null \
    | head -n1 \
    || true
)"


NEW_VERSION="$(
    printf '%s\n' "${NEW_VERSION_RAW}" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    || true
)"


if [[ "${NEW_VERSION}" != "${LATEST_VERSION}" ]]; then

    error "新版本二进制校验失败。"

    echo "预期版本：${LATEST_VERSION}"
    echo "实际版本：${NEW_VERSION:-unknown}"

    exit 1

fi


success "新版本验证通过：v${NEW_VERSION}"


# ============================================================
# Backup current binary
# ============================================================

mkdir -p "${BACKUP_DIR}"

BACKUP_FILE="${BACKUP_DIR}/ddns-go-$(
    date +%Y%m%d_%H%M%S
).bak"


info "备份当前程序..."

cp -a \
    "${INSTALL_PATH}" \
    "${BACKUP_FILE}"


success "旧版本备份：${BACKUP_FILE}"


# ============================================================
# Update
# ============================================================

SERVICE_WAS_ACTIVE=0

if systemctl is-active --quiet "${DDNS_SERVICE}"; then
    SERVICE_WAS_ACTIVE=1
fi


info "停止 ${DDNS_SERVICE}..."

systemctl stop "${DDNS_SERVICE}"


info "替换 DDNS-GO 二进制..."

install \
    -m 755 \
    "${NEW_BINARY}" \
    "${INSTALL_PATH}"


success "程序替换完成。"


# ============================================================
# Start service
# ============================================================

info "启动 ${DDNS_SERVICE}..."

systemctl daemon-reload

systemctl start "${DDNS_SERVICE}"


sleep 3


# ============================================================
# Health check
# ============================================================

if ! systemctl is-active --quiet "${DDNS_SERVICE}"; then

    error "新版本服务启动失败，开始自动回滚..."

    systemctl stop "${DDNS_SERVICE}" 2>/dev/null || true


    cp -a \
        "${BACKUP_FILE}" \
        "${INSTALL_PATH}"

    chmod 755 "${INSTALL_PATH}"

    systemctl daemon-reload

    systemctl start "${DDNS_SERVICE}"


    sleep 2


    if systemctl is-active --quiet "${DDNS_SERVICE}"; then

        success "已成功回滚到旧版本。"

        echo
        echo "请查看日志："
        echo
        echo "journalctl -u ${DDNS_SERVICE} -n 100 --no-pager"

    else

        error "回滚后服务仍无法启动。"

        echo
        echo "备份文件："
        echo "${BACKUP_FILE}"

    fi

    exit 1

fi


success "服务运行正常。"


# ============================================================
# Final version verification
# ============================================================

FINAL_VERSION_RAW="$(
    "${INSTALL_PATH}" -v 2>/dev/null \
    | head -n1 \
    || true
)"


FINAL_VERSION="$(
    printf '%s\n' "${FINAL_VERSION_RAW}" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    || true
)"


if [[ "${FINAL_VERSION}" != "${LATEST_VERSION}" ]]; then

    warn "服务已启动，但最终版本检测结果异常。"

    echo "检测结果：${FINAL_VERSION:-unknown}"

else

    success "最终版本：v${FINAL_VERSION}"

fi


# ============================================================
# Remove old backups
# Keep latest 3
# ============================================================

BACKUP_COUNT="$(
    find "${BACKUP_DIR}" \
        -maxdepth 1 \
        -type f \
        -name 'ddns-go-*.bak' \
        | wc -l
)"


if (( BACKUP_COUNT > 3 )); then

    info "清理旧备份，仅保留最近 3 个..."

    find "${BACKUP_DIR}" \
        -maxdepth 1 \
        -type f \
        -name 'ddns-go-*.bak' \
        -printf '%T@ %p\n' \
        | sort -nr \
        | tail -n +4 \
        | cut -d' ' -f2- \
        | xargs -r rm -f

fi


# ============================================================
# Final output
# ============================================================

echo
echo "============================================================"
echo " DDNS-GO 更新完成"
echo "============================================================"
echo
echo "旧版本：v${CURRENT_VERSION}"
echo "新版本：${LATEST_TAG}"
echo "程序：${INSTALL_PATH}"
echo "服务：${DDNS_SERVICE}"
echo "备份：${BACKUP_FILE}"
echo
echo "配置文件：未修改"
echo
echo "查看服务："
echo "  systemctl status ${DDNS_SERVICE}"
echo
echo "查看日志："
echo "  journalctl -u ${DDNS_SERVICE} -n 100 --no-pager"
echo
echo "============================================================"

success "DDNS-GO 更新成功。"
