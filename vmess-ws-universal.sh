#!/bin/bash
# ==============================================
# 通用版 VMess+WS 一键部署脚本
# 无任何固定端口，所有参数手动自定义输入
# 仅监听本地127.0.0.1，配合Nginx反代使用
# 自动系统更新、自动生成UUID、自动输出节点链接
# 开源协议：Apache-2.0
# ==============================================

# 校验必须root运行
if [ $EUID -ne 0 ]; then
    echo "错误：请以 root 权限运行此脚本！"
    exit 1
fi

clear
echo "====================================="
echo "   VMess+WS 通用一键部署脚本"
echo "   全参数自定义 无固定端口"
echo "====================================="

# 1. 系统升级 + 安装必备依赖
echo -e "\n[1/4] 升级系统并安装运行依赖..."
apt update -y && apt upgrade -y
apt install -y wget curl unzip jq

# 2. 交互式手动输入所有自定义参数
echo -e "\n[2/4] 请依次手动填写以下配置信息"
read -p "1. 输入已解析的域名: " DOMAIN
read -p "2. 输入VMess本地监听端口(1-65535): " VMESS_PORT
read -p "3. 输入WS路径(例 /ws  /vmess): " WSPATH

# 判空校验
if [[ -z "$DOMAIN" || -z "$VMESS_PORT" || -z "$WSPATH" ]]; then
    echo "错误：域名、端口、WS路径不能为空，请重新运行！"
    exit 1
fi

# 3. 自动生成标准随机UUID
echo -e "\n[3/4] 自动生成随机UUID..."
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "生成UUID：$UUID"

# 4. 安装官方 Xray 核心
echo -e "\n正在安装官方Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 5. 写入Xray配置 仅监听本地
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": $VMESS_PORT,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
      },
      "streamSecurity": "none",
      "network": "ws",
      "wsSettings": {
        "path": "$WSPATH"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# 6. 设置开机自启并重启Xray
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# 7. 组装并生成可直接导入的VMess节点链接
VMESS_JSON=$(jq -n \
--arg v "2" \
--arg ps "VMess-WS-通用" \
--arg add "$DOMAIN" \
--arg port "443" \
--arg id "$UUID" \
--arg aid "0" \
--arg scy "auto" \
--arg net "ws" \
--arg type "none" \
--arg host "$DOMAIN" \
--arg path "$WSPATH" \
--arg tls "tls" \
'{
  v: $v,
  ps: $ps,
  add: $add,
  port: $port,
  id: $id,
  aid: $aid,
  scy: $scy,
  net: $net,
  type: $type,
  host: $host,
  path: $path,
  tls: $tls
}')

B64_STR=$(echo -n "$VMESS_JSON" | base64 -w 0)
VMESS_LINK="vmess://$B64_STR"

# 8. 输出全部配置信息
echo -e "\n====================================="
echo "        部署完成 配置汇总"
echo "====================================="
echo "域名：$DOMAIN"
echo "VMess本地端口：$VMESS_PORT"
echo "WS路径：$WSPATH"
echo "UUID：$UUID"
echo "alterId：0"
echo "====================================="
echo "可直接导入节点链接："
echo "$VMESS_LINK"
echo "====================================="