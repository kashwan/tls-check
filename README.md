# VLESS + Reality 挑选域名脚本

一键检测目标网站是否符合 Xray VLESS + Reality 伪装域名的要求，省去逐项手动核对。

参考：[Xray Reality 自建教程 - AceSheep](https://blog.acesheep.com/p/xray-reality-protocol)

## 目标域名的标准

- 支持 TLS 1.3
- 使用 X25519 密钥交换
- 支持 HTTP/2 (H2)
- 不使用 CDN（Cloudflare / Amazon / Fastly）
- 国外网站，中国境内可直连访问
- 加分项：支持 OCSP Stapling

## 如何挑选域名

优先选 **VPS 所在地（附近）** 的网站，延迟低、流量特征自然：

- 当地旅游局、大学、学术研究机构、图书馆等公共机构网站
- 二次元、动漫、游戏等相关站点
- 自己的域名（自己控制 TLS 指纹，最稳）
- 同 ASN 邻居的域名

尽量避开大厂域名（Google、微软、苹果等），容易被识别；也不要用带 CDN 的站点。

## 用法

```bash
chmod +x tls-check.sh
./tls-check.sh www.nvidia.cn
```

也支持带协议前缀的写法：

```bash
./tls-check.sh https://www.nvidia.cn/some/path
```

## 检测项

| 检测项 | 说明 |
| --- | --- |
| Certificate valid | 证书是否有效 |
| TLS 1.3 support | 是否支持 TLS 1.3 |
| X25519 support | 是否支持 X25519 |
| AES-GCM support | 是否支持 AES-GCM |
| OCSP Stapling support | 是否支持 OCSP Stapling（加分项） |
| HTTP/2 (H2) support | 是否支持 HTTP/2 |
| Cloudflare / Amazon / Fastly CDN | 是否使用 CDN（使用则不适合） |

## 依赖

`bash`、`openssl`、`curl`、`timeout`（coreutils）

## 注意

脚本只检测协议与 CDN 特征，**不检测中国境内连通性**。请再用 [ITDOG](https://www.itdog.cn/ping/) 对 443 端口做 TCP Ping，确认没有省份 100% 丢包。

## License

MIT
