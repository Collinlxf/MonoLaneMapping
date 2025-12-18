#!/bin/bash
# MonoLaneMapping Docker 构建和运行脚本

set -e

DOCKER_NAME="monolane"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"  # 自动获取项目父目录

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 构建Docker镜像
build_docker() {
    print_info "开始构建Docker镜像: ${DOCKER_NAME}"
    cd "${SCRIPT_DIR}"
    docker build -t ${DOCKER_NAME}:latest .
    print_info "Docker镜像构建完成!"
}

# 运行Docker容器
run_docker() {
    print_info "启动Docker容器: ${DOCKER_NAME}"
    
    # 检查是否已有同名容器在运行
    if docker ps -a --format '{{.Names}}' | grep -q "^${DOCKER_NAME}$"; then
        print_warn "发现已存在的容器 ${DOCKER_NAME}，正在删除..."
        docker rm -f ${DOCKER_NAME}
    fi
    
    docker run -itd \
        --name ${DOCKER_NAME} \
        --privileged \
        --network host \
        -v ${WORKSPACE_DIR}:/workspace:rw \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -e DISPLAY=${DISPLAY} \
        -e QT_X11_NO_MITSHM=1 \
        -w /workspace/MonoLaneMapping \
        ${DOCKER_NAME}:latest \
        bash -c "tail -f /dev/null"
}

# 进入已运行的容器
exec_docker() {
    print_info "进入Docker容器: ${DOCKER_NAME}"
    docker exec -it ${DOCKER_NAME} bash
}

# 启动已停止的容器
start_docker() {
    print_info "启动已停止的容器: ${DOCKER_NAME}"
    docker start -i ${DOCKER_NAME}
}

# 停止容器
stop_docker() {
    print_info "停止Docker容器: ${DOCKER_NAME}"
    docker stop ${DOCKER_NAME}
}

# 删除容器和镜像
clean_docker() {
    print_warn "清理Docker容器和镜像: ${DOCKER_NAME}"
    docker rm -f ${DOCKER_NAME} 2>/dev/null || true
    docker rmi ${DOCKER_NAME}:latest 2>/dev/null || true
    print_info "清理完成!"
}

# 显示帮助
show_help() {
    echo "MonoLaneMapping Docker 管理脚本"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "命令:"
    echo "  build   - 构建Docker镜像"
    echo "  run     - 运行新的Docker容器"
    echo "  exec    - 进入已运行的容器"
    echo "  start   - 启动已停止的容器"
    echo "  stop    - 停止容器"
    echo "  clean   - 删除容器和镜像"
    echo "  help    - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build   # 首次使用，构建镜像"
    echo "  $0 run     # 构建后，运行容器"
    echo "  $0 exec    # 容器运行中，新开终端进入"
}

# 主逻辑
case "${1}" in
    build)
        build_docker
        ;;
    run)
        run_docker
        ;;
    exec)
        exec_docker
        ;;
    start)
        start_docker
        ;;
    stop)
        stop_docker
        ;;
    clean)
        clean_docker
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [ -z "$1" ]; then
            show_help
        else
            print_error "未知命令: $1"
            show_help
            exit 1
        fi
        ;;
esac
