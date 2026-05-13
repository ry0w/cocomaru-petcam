#!/bin/bash
# ============================================
# HTTPS証明書生成スクリプト (mkcert使用)
# ============================================
# WebRTCはHTTPS環境が必須です（localhost除く）
# このスクリプトでローカル開発用の証明書を生成します

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"

mkdir -p "$CERT_DIR"

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
  echo "============================================"
  echo "  mkcert がインストールされていません"
  echo "============================================"
  echo ""
  echo "インストール方法:"
  echo ""
  echo "  [macOS]"
  echo "    brew install mkcert"
  echo "    brew install nss  # Firefox対応"
  echo ""
  echo "  [Windows (Chocolatey)]"
  echo "    choco install mkcert"
  echo ""
  echo "  [Windows (Scoop)]"
  echo "    scoop install mkcert"
  echo ""
  echo "  [Linux]"
  echo "    sudo apt install libnss3-tools"
  echo "    curl -JLO https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v*-linux-amd64"
  echo "    sudo install mkcert-v*-linux-amd64 /usr/local/bin/mkcert"
  echo ""
  exit 1
fi

echo "ローカルCAをインストール中..."
mkcert -install

echo "証明書を生成中..."
cd "$CERT_DIR"
mkcert -key-file localhost-key.pem -cert-file localhost.pem \
  localhost 127.0.0.1 ::1 \
  "$(hostname)" \
  "$(hostname).local"

echo ""
echo "============================================"
echo "  証明書の生成が完了しました!"
echo "============================================"
echo "  場所: $CERT_DIR/"
echo "  - localhost.pem (証明書)"
echo "  - localhost-key.pem (秘密鍵)"
echo ""
echo "  サーバー起動: cd server && npm start"
echo "============================================"
