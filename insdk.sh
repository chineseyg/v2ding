#!/bin/bash
# Ubuntu 22.04 (jammy) 自动化初始化脚本
# - 自动识别架构: amd64 用 ubuntu/, arm64 用 ubuntu-ports/
# - 自动选择国内镜像: 阿里云 > 清华 > 中科大 (逐一探测连通性, 全失败兜底阿里云)
# - 一键 apt 更新 + 安装依赖 + 配置 SSH(端口 2222, root 可登录)

set -e

# ---------- 1. 识别架构 ----------
ARCH="$(uname -m)"
case "$ARCH" in
  *aarch64*|*arm64*) BASE="ubuntu-ports";;
  *)                 BASE="ubuntu";;
esac
echo ">>> 检测到架构: $ARCH  -> 使用源目录: $BASE/"

# ---------- 2. 探测镜像连通性 ----------
PROBE() {
  # 优先 curl, 其次 wget, 都没有则用 /dev/tcp
  if command -v curl >/dev/null 2>&1; then
    curl -fsI --connect-timeout 3 --max-time 6 "http://$1/$2/dists/jammy/InRelease" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then
    wget -q --spider -T 6 "http://$1/$2/dists/jammy/InRelease" 2>/dev/null
  else
    H="${1%%/*}"
    (exec 3<>"/dev/tcp/$H/80") 2>/dev/null
  fi
}

MIRROR=""
for M in mirrors.aliyun.com mirrors.tuna.tsinghua.edu.cn mirrors.ustc.edu.cn; do
  if PROBE "$M" "$BASE"; then MIRROR="$M"; break; fi
done
[ -n "$MIRROR" ] || MIRROR="mirrors.aliyun.com"
echo ">>> 使用镜像源: http://$MIRROR/$BASE/"

# ---------- 3. 写入 sources.list ----------
: > /etc/apt/sources.list
for C in "" -updates -security -backports; do
  echo "deb http://$MIRROR/$BASE/ jammy$C main restricted universe multiverse" >> /etc/apt/sources.list
done
cat /etc/apt/sources.list

# ---------- 4. 更新并安装依赖 ----------
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
  python3 python3-pip openssh-server git libpcap-dev wget curl screen

# ---------- 5. 配置 SSH (端口 2222, root 可密码登录) ----------
mkdir -p /run/sshd
ssh-keygen -A
echo "root:Asd123." | chpasswd
sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "Port 2222" >> /etc/ssh/sshd_config
service ssh start

echo ">>> 初始化完成: SSH 已启动, 端口 2222, root/Asd123."
