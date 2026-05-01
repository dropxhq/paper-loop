default:
    just --list

# 启动后端开发服务器
backend:
    cd backend && uv run uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# 安装后端依赖
backend-install:
    cd backend && uv sync
