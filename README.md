markdown
# OneKey-VPS-Tools-Uni
VPS 通用一键部署工具箱（无端口限制版）
适配所有 Ubuntu / Debian 系统，全部参数自定义手动输入，无固定端口、无内置限制。

## 项目介绍
包含两个独立一键脚本：
1. `vmess-ws-universal.sh`  
   部署 VMess+WS 节点，仅监听本地 127.0.0.1，自动生成 UUID、自动生成可导入客户端节点链接。

2. `cloudreve-nginx-universal.sh`  
   部署 Cloudreve 个人网盘 + Nginx 反向代理分流，可手动填入 VMess 端口，自动生成 Nginx 配置，无需手动改配置文件。

## 部署顺序（必看）
1. 先运行：`vmess-ws-universal.sh`  
   记录好：域名、VMess本地端口、WS路径、UUID
2. 再运行：`cloudreve-nginx-universal.sh`  
   逐项填入：相同域名、相同WS路径、以及第一步的 VMess 端口  
   脚本自动写入 Nginx 分流配置，直接生效。

## 手动输入参数说明
### 一、VMess 脚本需要输入
- 域名：已解析到 VPS IP 的域名
- VMess 本地端口：自定义 1-65535 未占用端口
- WS 路径：自定义，示例 `/ws` `/vmess`

### 二、Cloudreve 脚本需要输入
1. 域名（和 VMess 保持一致）
2. Nginx 监听端口（自定义）
3. WS 路径（和 VMess 保持一致）
4. Cloudreve 本地端口（自定义）
5. VMess 本地端口（填 VMess 脚本里设置的端口）

## Cloudflare 推荐配置
1. SSL/TLS 模式：**灵活**
2. 开启小黄云代理
3. Nginx 对外端口可走 443 配合域名 TLS

## 常用管理命令
### Xray（VMess）
```bash
systemctl start xray
systemctl stop xray
systemctl restart xray
systemctl status xray
Cloudreve 网盘
bash
systemctl start cloudreve
systemctl stop cloudreve
systemctl restart cloudreve
# 查看初始账号密码
journalctl -u cloudreve
Nginx 服务
bash
# 校验配置
nginx -t
# 重启服务
systemctl restart nginx
使用要求
•必须 root 权限运行脚本
•域名提前解析到 VPS 公网 IP
•服务器防火墙放行你自定义的所有端口
•端口不能被其他程序占用
开源协议
Apache-2.0 开源协议，可自由使用、修改、二次分发。
免责声明
仅用于个人学习与合法网络环境使用，禁止用于违规用途，使用风险自行承担。