#!/usr/bin/env bash
# 用法: ./check.sh example.com

set -u

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "用法: $0 <域名>"
  echo "示例: $0 www.nvidia.cn"
  exit 1
fi

# 去掉协议前缀和路径
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"

# 256 色定义
GREEN="\033[38;5;46m"
RED="\033[38;5;196m"
YELLOW="\033[38;5;226m"
RESET="\033[0m"

CHECK="✔"
CROSS="✘"

echo -e "--- Checking ${DOMAIN}:443 ---"

# ==========================================
# 1. 基础 TLS / 证书
# ==========================================
OPENSSL_OUT=$(timeout 10s openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" -status < /dev/null 2>&1 || true)

if echo "$OPENSSL_OUT" | grep -q "Verify return code: 0 (ok)"; then
  printf "%-24s ${GREEN}%s Valid${RESET}\n" "Certificate valid:" "$CHECK"
else
  printf "%-24s ${RED}%s Invalid${RESET}\n" "Certificate valid:" "$CROSS"
fi

# ==========================================
# 2. TLS 1.3
# ==========================================
TLS13_OUT=$(timeout 10s openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" -tls1_3 < /dev/null 2>&1 || true)
if echo "$TLS13_OUT" | grep -q "Protocol.*TLSv1.3"; then
  printf "%-24s ${GREEN}%s Supported${RESET}\n" "TLS 1.3 support:" "$CHECK"
else
  printf "%-24s ${RED}%s Not Supported${RESET}\n" "TLS 1.3 support:" "$CROSS"
fi

# ==========================================
# 3. X25519
# ==========================================
X25519_OUT=$(timeout 10s openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" -groups X25519 < /dev/null 2>&1 || true)
if echo "$X25519_OUT" | grep -q "Verify return code: 0 (ok)"; then
  printf "%-24s ${GREEN}%s Supported${RESET}\n" "X25519 support:" "$CHECK"
else
  printf "%-24s ${RED}%s Not Supported${RESET}\n" "X25519 support:" "$CROSS"
fi

# ==========================================
# 4. AES-GCM (修复版)
# ==========================================
# 强制使用 TLS 1.2 进行 AES 测试
AES_OUT=$(timeout 10s openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" -tls1_2 -cipher 'ECDHE+AESGCM' < /dev/null 2>&1 || true)

# 兼容 TLS 1.2 (AES128-GCM) 和 TLS 1.3 (TLS_AES_128_GCM) 的命名
if echo "$AES_OUT" | grep -qiE "Cipher is (.*AES.*GCM|TLS_AES_.*GCM)"; then
  printf "%-24s ${GREEN}%s Supported${RESET}\n" "AES-GCM support:" "$CHECK"
else
  printf "%-24s ${RED}%s Not Supported${RESET}\n" "AES-GCM support:" "$CROSS"
fi

# ==========================================
# 5. OCSP Stapling
# ==========================================
if echo "$OPENSSL_OUT" | grep -q "OCSP Response Status: successful"; then
  printf "%-24s ${GREEN}%s Supported${RESET}\n" "OCSP Stapling support:" "$CHECK"
else
  printf "%-24s ${YELLOW}%s Not Supported${RESET}\n" "OCSP Stapling support:" "$CROSS"
fi

# ==========================================
# 6. HTTP/2
# ==========================================
HTTP2_HEAD=$(curl -sI --http2 "https://$DOMAIN" 2>/dev/null || true)
if echo "$HTTP2_HEAD" | head -n1 | grep -qi "HTTP/2"; then
  printf "%-24s ${GREEN}%s Supported${RESET}\n" "HTTP/2 (H2) support:" "$CHECK"
else
  printf "%-24s ${RED}%s Not Supported${RESET}\n" "HTTP/2 (H2) support:" "$CROSS"
fi

# ==========================================
# 7. CDN
# ==========================================
HEADERS=$(curl -sI -L "https://$DOMAIN" 2>/dev/null || true)
TRACE_OUT=$(curl -s --max-time 5 "https://$DOMAIN/cdn-cgi/trace" 2>/dev/null || true)

if echo "$TRACE_OUT" | grep -qE "^(fl|h|ip|ts)=" || echo "$HEADERS" | grep -qiE "^(cf-ray|server:.*cloudflare)"; then
  printf "%-24s ${RED}%s In use${RESET}\n" "Cloudflare CDN:" "$CROSS"
else
  printf "%-24s ${GREEN}%s Not in use${RESET}\n" "Cloudflare CDN:" "$CHECK"
fi

if echo "$HEADERS" | grep -qiE "^(x-amz-cf-id|server:.*cloudfront|via:.*cloudfront|x-cache:.*cloudfront)"; then
  printf "%-24s ${RED}%s In use${RESET}\n" "Amazon CDN:" "$CROSS"
else
  printf "%-24s ${GREEN}%s Not in use${RESET}\n" "Amazon CDN:" "$CHECK"
fi

if echo "$HEADERS" | grep -qiE "^(x-fastly|fastly-debug|server:.*fastly|via:.*fastly|x-served-by:.*fastly)"; then
  printf "%-24s ${RED}%s In use${RESET}\n" "Fastly CDN:" "$CROSS"
else
  printf "%-24s ${GREEN}%s Not in use${RESET}\n" "Fastly CDN:" "$CHECK"
fi

echo -e "--------------------------------------"
