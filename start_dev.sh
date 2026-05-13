#!/bin/bash
# ============================================
# ココ丸ちゃんねる 開発サーバー起動スクリプト
# ============================================
# 1. Flutter Webをビルド
# 2. シグナリングサーバーを起動
# 3. HTTPS Webサーバーを起動
# ============================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$PROJECT_DIR/server"

echo "============================================"
echo "  ココ丸ちゃんねる 開発環境セットアップ"
echo "============================================"
echo ""

# Step 1: Install server dependencies
echo "[1/4] サーバーの依存パッケージをインストール中..."
cd "$SERVER_DIR"
if [ ! -d "node_modules" ]; then
  npm install
fi

# Step 2: Check for HTTPS certs
echo "[2/4] HTTPS証明書を確認中..."
if [ ! -f "$SERVER_DIR/certs/localhost.pem" ]; then
  echo ""
  echo "  ⚠ HTTPS証明書が見つかりません"
  echo "  証明書を生成するには:"
  echo "    cd server && ./generate_certs.sh"
  echo ""
  echo "  HTTPモードで続行します..."
  echo ""
fi

# Step 3: Build Flutter Web
echo "[3/4] Flutter Webをビルド中..."
cd "$PROJECT_DIR"
flutter build web

# Step 4: Start servers
echo "[4/4] サーバーを起動中..."
echo ""

# Start signaling server in background
cd "$SERVER_DIR"
node signaling_server.js &
SIGNALING_PID=$!

# Start web dev server
node dev_server.js &
WEB_PID=$!

echo ""
echo "============================================"
echo "  起動完了!"
echo "============================================"
echo "  停止するには Ctrl+C を押してください"
echo "============================================"

# Cleanup on exit
cleanup() {
  echo ""
  echo "サーバーを停止中..."
  kill $SIGNALING_PID 2>/dev/null || true
  kill $WEB_PID 2>/dev/null || true
  echo "停止しました"
}
trap cleanup EXIT INT TERM

# Wait for both processes
wait
