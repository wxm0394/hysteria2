# 旧脚本审计记录

范围：install.sh、phy2.sh、README.md，以及 hysteria2.py 的前半部分。hysteria2.py 后半部分因输出被截断，尚未审计。

## 发现

1. install.sh 会从 hy2.crazyact.com 下载文件写入 /usr/local/bin/hy2 并设为可执行，之后以 root 运行。来源是第三方，内容无法确认。
2. install.sh 对生成的 TLS 私钥和证书执行 chmod 777，本机任何用户都能读取私钥。
3. install.sh 用明文 HTTP (ip-api.com) 并关闭证书检查 (--no-check-certificate) 查询服务器 IP。
4. install.sh 提供安装第三方 xanmod 内核和清理旧内核的选项，会改动系统启动项。
5. hysteria2.py 创建的 hy2 快捷命令，每次运行都从 seagullz4/hysteria2 的 main 分支下载最新代码并以 root 执行。上游以后的任何改动都会在你的服务器上执行。
6. hysteria2.py 把用户输入的密码、混淆密码、伪装网址直接拼进 YAML，没有转义。
7. README 里的安装命令指向 seagullz4/hysteria2，而不是本仓库。
8. 好的一面：hysteria2.py 的安装和卸载使用 Hysteria 官方 get.hy2.sh，版本号输入做了格式校验。

## 建议

不要在生产服务器上运行根目录的 install.sh 和 hysteria2.py。请使用 safe/ 下的文件。
