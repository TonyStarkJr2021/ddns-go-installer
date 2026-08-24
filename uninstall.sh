#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.0"

PROGRAM="/usr/local/bin/ddns-go"
SERVICE_NAME="ddns-go.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

INSTALLER_DIR="/usr/local/share/ddns-go-installer"
BACKUP_DIR="${INSTALLER_DIR}/backups"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

echo
echo "============================================================"
echo " DDNS-GO Universal Uninstaller v${VERSION}"
echo "============================================================"
echo

# ============================================================
# Root 检查
# ============================================================

[[ "${EUID}" -eq 0 ]] || die "请使用 root 用户运行此脚本。"

# ============================================================
# systemd 检查
# ============================================================

if [[ "$(ps -p 1 -o comm= 2>/dev/null || true)" != "systemd" ]]; then
    die "当前系统不是 systemd 环境。"
fi

ok "Init system: systemd"

# ============================================================
# 检测安装状态
# ============================================================

FOUND_PROGRAM=0
FOUND_SERVICE=0

if [[ -f "${PROGRAM}" ]]; then
    FOUND_PROGRAM=1

    CURRENT_VERSION="$("${PROGRAM}" -v 2>/dev/null | head -n1 || true)"

    if [[ -n "${CURRENT_VERSION}" ]]; then
        ok "检测到 DDNS-GO：${CURRENT_VERSION}"
    else
        ok "检测到 DDNS-GO：${PROGRAM}"
    fi
else
    warn "未检测到程序：${PROGRAM}"
fi

if [[ -f "${SERVICE_FILE}" ]] || systemctl cat "${SERVICE_NAME}" >/dev/null 2>&1; then
    FOUND_SERVICE=1
    ok "检测到服务：${SERVICE_NAME}"
else
    warn "未检测到服务：${SERVICE_NAME}"
fi

if [[ "${FOUND_PROGRAM}" -eq 0 && "${FOUND_SERVICE}" -eq 0 ]]; then
    echo
    warn "未检测到通过本安装器部署的 DDNS-GO。"
    exit 0
fi

# ============================================================
# 显示将执行的操作
# ============================================================

echo
echo "即将卸载："
echo

[[ "${FOUND_PROGRAM}" -eq 1 ]] && echo "  程序：${PROGRAM}"
[[ "${FOUND_SERVICE}" -eq 1 ]] && echo "  服务：${SERVICE_NAME}"

if [[ -d "${BACKUP_DIR}" ]]; then
    echo "  安装器备份：${BACKUP_DIR}"
fi

echo
warn "DDNS-GO 的配置文件不会被此步骤删除。"
echo

read -r -p "确认卸载 DDNS-GO？ [y/N]: " CONFIRM

case "${CONFIRM}" in
    y|Y|yes|YES|Yes)
        ;;
    *)
        info "已取消卸载。"
        exit 0
        ;;
esac

# ============================================================
# 停止并禁用服务
# ============================================================

echo

if systemctl cat "${SERVICE_NAME}" >/dev/null 2>&1; then
    info "停止 ${SERVICE_NAME}..."

    systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
    ok "服务已停止。"

    info "禁用 ${SERVICE_NAME}..."

    systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
    ok "服务已禁用。"
fi

# ============================================================
# 删除 systemd 服务
# ============================================================

if [[ -f "${SERVICE_FILE}" ]]; then
    info "删除 systemd 服务..."

    rm -f "${SERVICE_FILE}"

    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1 || true

    ok "systemd 服务已删除。"
fi

# ============================================================
# 删除程序
# ============================================================

if [[ -f "${PROGRAM}" ]]; then
    info "删除 DDNS-GO 程序..."

    rm -f "${PROGRAM}"

    ok "程序已删除。"
fi

# ============================================================
# 删除安装器备份
# ============================================================

if [[ -d "${INSTALLER_DIR}" ]]; then
    echo
    read -r -p "是否删除 DDNS-GO Installer 产生的历史程序备份？ [y/N]: " DELETE_BACKUPS

    case "${DELETE_BACKUPS}" in
        y|Y|yes|YES|Yes)
            rm -rf "${INSTALLER_DIR}"
            ok "安装器备份已删除。"
            ;;
        *)
            info "保留安装器备份：${INSTALLER_DIR}"
            ;;
    esac
fi

# ============================================================
# 最终检查
# ============================================================

echo
info "执行卸载后检查..."

ERROR_COUNT=0

if [[ -e "${PROGRAM}" ]]; then
    error "程序仍然存在：${PROGRAM}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
else
    ok "DDNS-GO 程序已移除。"
fi

if systemctl cat "${SERVICE_NAME}" >/dev/null 2>&1; then
    error "systemd 服务仍然存在：${SERVICE_NAME}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
else
    ok "DDNS-GO systemd 服务已移除。"
fi

if [[ "${ERROR_COUNT}" -ne 0 ]]; then
    die "卸载检查失败，请检查上方错误。"
fi

# ============================================================
# 完成
# ============================================================

echo
echo "============================================================"
echo " DDNS-GO 卸载完成"
echo "============================================================"
echo
echo "程序：已删除"
echo "服务：已删除"
echo
echo "DDNS-GO 配置文件未主动删除。"

if [[ -d "${INSTALLER_DIR}" ]]; then
    echo "安装器备份：已保留"
    echo "位置：${INSTALLER_DIR}"
else
    echo "安装器备份：已删除"
fi

echo
ok "DDNS-GO 卸载成功。"
