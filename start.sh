#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

# Kill old
kill $(lsof -ti:8000 2>/dev/null) 2>/dev/null || true
kill $(lsof -ti:3000 2>/dev/null) 2>/dev/null || true
sleep 1

# Build frontend
echo "► 构建前端..."
cd "$DIR/frontend"
npx vite build --logLevel error

# Start backend (port 8000)
echo "► 启动后端..."
cd "$DIR/backend"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
sleep 2

# Start static server (port 3000)
echo "► 启动前端..."
cd "$DIR/frontend"
python3 -m http.server 3000 --directory dist &

sleep 2
echo ""
echo "====================================="
echo "  前端: http://localhost:3000"
echo "  后端: http://localhost:8000"
echo "  API:  http://localhost:8000/docs"
echo "====================================="
echo ""
echo "按 Ctrl+C 停止"
wait
