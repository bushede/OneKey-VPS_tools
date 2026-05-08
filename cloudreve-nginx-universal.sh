#!/bin/bash
# ==============================================
# Cloudreve + Nginx 通用一键部署脚本
# 全参数手动自定义输入，包含VMess端口手动填写
# 自动生成Nginx分流配置，无需手动修改配置文件
# 开源协议：Apache-2.0
# ==============================================

# 校验必须root运行
if [ $EUID -ne 0 ]; then
    echo "错误：请以 root 权限运行此脚本！"
    exit 1
fi

clear
echo "====================================="
echo " Cloudreve+Nginx 通用一键部署脚本"
echo " 全参数自定义 自动Nginx分流"
echo "====================================="

# 1. 手动输入全部自定义参数（含VMess端口）
echo -e "\n请依次填写所有配置信息"
read -p "1. 输入域名(与VMess保持一致): " DOMAIN
read -p "2. 输入Nginx对外监听端口: " NGINX_PORT
read -p "3. 输入WS路径(与VMess保持一致): " WSPATH
read -p "4. 输入Cloudreve本地端口(自定义): " CLOUDREVE_PORT
read -p "5. 输入VMess本地端口(VMess脚本设置的端口): " VMESS_PORT

# 判空校验
if [[ -z "$DOMAIN" || -z "$NGINX_PORT" || -z "$WSPATH" || -z "$CLOUDREVE_PORT" || -z "$VMESS_PORT" ]]; then
    echo "错误：所有配置项都不能为空，请重新运行！"
    exit 1
fi

# 2. 系统升级 + 安装依赖
echo -e "\n[1/4] 升级系统并安装Nginx及依赖..."
apt update -y && apt upgrade -y
apt install -y wget tar nginx

# 3. 下载安装并配置Cloudreve网盘
echo -e "\n[2/4] 安装配置Cloudreve网盘..."
mkdir -p /opt/cloudreve
cd /opt/cloudreve

wget -N https://github.com/cloudreve/Cloudreve/releases/download/3.8.3/cloudreve_3.8.3_linux_amd64.tar.gz
tar -zxvf cloudreve_3.8.3_linux_amd64.tar.gz
chmod +x cloudreve

# 生成Cloudreve配置
cat > conf.ini <<EOF
[System]
Listen = :$CLOUDREVE_PORT
Debug = false
SessionSecret = $(head -c 16 /dev/urandom | xxd -An -ps)
EOF

# 配置系统服务开机自启
cat > /etc/systemd/system/cloudreve.service <<EOF
[Unit]
Description=Cloudreve Personal Cloud Disk
After=network.target

[Service]
WorkingDirectory=/opt/cloudreve
ExecStart=/opt/cloudreve/cloudreve
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudreve
systemctl start cloudreve

# 4. 自动生成Nginx分流配置（自动填入VMess端口）
echo -e "\n[3/4] 自动生成Nginx反向代理分流配置..."
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN.conf"

# 删除默认站点避免冲突
rm -f /etc/nginx/sites-enabled/default

# 写入配置，自动带入所有自定义端口和路径
cat > $NGINX_CONF <<EOF
server {
    listen $NGINX_PORT;
    server_name $DOMAIN;

    # 根目录反代 Cloudreve 网盘
    location / {
        proxy_pass http://127.0.0.1:$CLOUDREVE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_connect_timeout 60s;
        proxy_read_timeout 600s;
    }

    # WS路径反代 VMess 节点
    location $WSPATH {
        proxy_pass http://127.0.0.1:$VMESS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
}
EOF

# 启用站点配置
ln -sf $NGINX_CONF $NGINX_LINK

# 校验Nginx配置并重启
nginx -t
if [ $? -eq 0 ]; then
    systemctl restart nginx
    echo "Nginx配置校验成功，已重启生效！"
else
    echo "Nginx配置语法错误，请检查端口和路径！"
    exit 1
fi

# 5. 输出部署汇总信息
echo -e "\n====================================="
echo "        部署配置信息汇总"
echo "====================================="
echo "域名：$DOMAIN"
echo "Nginx监听端口：$NGINX_PORT"
echo "WS分流路径：$WSPATH"
echo "Cloudreve本地端口：$CLOUDREVE_PORT"
echo "VMess本地端口：$VMESS_PORT"
echo "====================================="
echo "查看Cloudreve初始账号密码："
echo "journalctl -u cloudreve"
echo "====================================="