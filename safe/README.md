# safe/ — Hysteria 2 可审计部署与测试

这里的文件只使用 Hysteria 官方安装器 (https://get.hy2.sh/)，不依赖第三方下载地址。
Hysteria 2 基于 QUIC/UDP，能否解决你网络上的 TCP 连接问题需要实测，不能保证。

## 1. 本机回环测试（Kali，普通用户）

1. 安装 hysteria 二进制（见官方文档），或用 HYSTERIA_BIN 指向它。
2. 运行 `bash safe/local-test/local_test.sh`。
3. 输出 PASS 表示：配置格式、证书指纹固定、客户端到服务端隧道在本机可用。

## 2. 服务器部署（root）

`sudo bash safe/server/setup.sh 8443 www.bing.com`

- 只创建 Hysteria 服务，不动 Xray、内核和现有 iptables。
- 官方安装器会先保存到临时文件并打印 sha256，按回车后才执行。
- 结束时打印密码和证书 SHA256，请自行保存，不要提交到仓库。
- 服务商面板如果有网络防火墙，需要另外放行对应 UDP 端口。

## 3. 客户端

把 `safe/client/mihomo-node.yaml.example` 的内容并入你的配置，替换占位符。

## 4. 注意

- 不要把真实 IP、密码、指纹提交到仓库。
- 根目录旧脚本的风险见 `SECURITY-NOTES.md`，不建议在服务器上运行。
