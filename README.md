# DDNS-GO Universal Installer

一个用于 [DDNS-GO](https://github.com/jeessy2/ddns-go) 的 Linux 通用安装、更新与卸载工具。

支持自动识别 Linux 发行版、CPU 架构，并从 DDNS-GO 官方 GitHub Release 获取最新版本。

---

## ✨ 功能

- 自动获取 DDNS-GO 最新版本
- 自动识别 CPU 架构
- 自动安装所需依赖
- 自动下载并验证 DDNS-GO 二进制文件
- 自动创建并管理 systemd 服务
- 支持一键安装、更新和卸载
- 更新前自动备份当前 DDNS-GO 程序
- 更新后自动验证程序版本及服务状态
- 更新过程不修改现有 DDNS-GO 配置
- 卸载时默认保留 DDNS-GO 配置文件
- 可选择是否清理 Installer 产生的历史程序备份

---

## 🐧 Linux 支持

适用于使用 **systemd** 的常见 Linux 发行版。

支持以下包管理器：

- `apt`
- `dnf`
- `yum`
- `pacman`
- `zypper`

例如：

- Debian
- Ubuntu
- CentOS
- Rocky Linux
- AlmaLinux
- Fedora
- Arch Linux
- openSUSE

> 实际兼容性取决于系统环境及 DDNS-GO 官方二进制支持情况。

### 已测试环境

目前已完成完整安装、更新及卸载测试：

| 系统 | 架构 | DDNS-GO | 状态 |
|---|---|---|---|
| Debian 12 (Bookworm) | x86_64 | v6.17.6 | ✅ 已测试 |

其他发行版已加入兼容处理，欢迎反馈实际运行结果。

---

## 🖥️ CPU 架构

安装及更新脚本会自动识别当前 CPU 架构，并匹配 DDNS-GO 官方 Release 中对应的安装包。

无需手动选择安装包。

> 实际可用架构取决于 DDNS-GO 官方 Release 当前提供的二进制文件。

---

## 🚀 一键安装

使用 `root` 用户执行：

    bash <(curl -fsSL https://raw.githubusercontent.com/TonyStarkJr2021/ddns-go-installer/main/install.sh)

安装脚本会自动：

1. 检测 Linux 系统及 systemd
2. 检查并安装所需依赖
3. 识别 CPU 架构
4. 获取 DDNS-GO 最新版本
5. 下载并验证程序
6. 安装 DDNS-GO
7. 创建 systemd 服务
8. 设置开机自动启动
9. 启动 DDNS-GO

安装完成后，默认 Web 管理端口：

    9876

首次配置可访问：

    http://服务器IP:9876

> 如果服务器启用了防火墙，需要自行放行 `9876` 端口，或根据自己的网络环境配置反向代理。

---

## 🔄 一键更新

    bash <(curl -fsSL https://raw.githubusercontent.com/TonyStarkJr2021/ddns-go-installer/main/update.sh)

更新脚本会自动：

- 检测当前 DDNS-GO 安装位置
- 检测 DDNS-GO systemd 服务
- 获取当前版本
- 查询 DDNS-GO 官方最新版本
- 判断是否需要更新
- 下载并验证新版本
- 更新前备份当前程序
- 安全停止 DDNS-GO 服务
- 替换 DDNS-GO 二进制文件
- 重新启动服务
- 验证服务运行状态
- 验证最终程序版本

如果当前已经是最新版，则不会执行替换操作。

### 🛡️ 更新保护

更新前会自动备份当前 DDNS-GO 二进制程序，以便出现异常时保留旧版本程序副本。

程序备份默认保存在：

    /usr/local/share/ddns-go-installer/backups

> [!IMPORTANT]
> 更新操作仅替换 DDNS-GO 程序本体，不主动修改现有 DDNS-GO 配置。

DDNS-GO 程序默认位置：

    /usr/local/bin/ddns-go

---

## 🗑️ 一键卸载

    bash <(curl -fsSL https://raw.githubusercontent.com/TonyStarkJr2021/ddns-go-installer/main/uninstall.sh)

卸载脚本会自动：

- 检测 DDNS-GO 程序
- 检测 DDNS-GO systemd 服务
- 请求用户确认
- 停止 DDNS-GO 服务
- 禁用开机启动
- 删除 systemd 服务
- 删除 DDNS-GO 程序
- 检查卸载结果

### ⚠️ 配置文件保护

> [!IMPORTANT]
> 卸载操作默认不会主动删除 DDNS-GO 配置文件。

这样在重新安装 DDNS-GO 时，可以继续保留原有配置。

卸载过程中还会询问是否删除 Installer 创建的历史程序备份：

    /usr/local/share/ddns-go-installer

如果选择保留，则 Installer 产生的程序备份不会被删除。

---

## 🛠️ 常用命令

### 查看服务状态

    systemctl status ddns-go.service

### 查看运行日志

    journalctl -u ddns-go.service -n 100 --no-pager

### 实时查看日志

    journalctl -u ddns-go.service -f

### 重启 DDNS-GO

    systemctl restart ddns-go.service

### 查看 DDNS-GO 版本

    /usr/local/bin/ddns-go -v

---

## 📂 默认路径

| 项目 | 路径 |
|---|---|
| DDNS-GO 程序 | `/usr/local/bin/ddns-go` |
| systemd 服务 | `ddns-go.service` |
| Web 管理端口 | `9876` |
| Installer 数据 | `/usr/local/share/ddns-go-installer` |
| 更新程序备份 | `/usr/local/share/ddns-go-installer/backups` |

---

## ⚠️ 注意事项

- 建议使用 `root` 用户运行脚本
- 系统需要使用 `systemd`
- 安装及更新需要能够正常访问 GitHub
- 如果服务器启用了防火墙，请自行放行需要使用的 Web 管理端口
- 如果通过反向代理访问 DDNS-GO，可根据自己的环境关闭公网对 `9876` 端口的直接访问
- 更新前虽然会自动备份 DDNS-GO 程序，但重要配置仍建议自行做好备份
- 本项目不会修改 DDNS-GO 上游程序本身，仅负责安装、更新、卸载及 systemd 服务管理

---

## 🔗 上游项目

- [DDNS-GO](https://github.com/jeessy2/ddns-go)

本项目仅提供 DDNS-GO 的 Linux 安装、更新及卸载自动化脚本。

DDNS-GO 本体及相关功能由其上游项目维护。

---

## ⭐ Support

如果这个项目对你有帮助，欢迎点一个 **Star**。

如发现安装、更新或兼容性问题，也欢迎提交 **Issue**。
