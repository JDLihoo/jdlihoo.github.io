#!/bin/bash

# 运行示例: ./offline-slow-node.sh --num-npus 4 --slow-rank-id 0
# --- 默认参数设置 ---
NUM_NPUS=4
SLOW_RANK_ID=0

# --- 参数解析 (支持 --num-npus 和 --slow-rank-id) ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --num-npus)
      NUM_NPUS="$2"
      shift 2
      ;;
    --slow-rank-id)
      SLOW_RANK_ID="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

NUM_NPUS_PER_NODE=$((NUM_NPUS / 2))

echo "------------------------------------------------"
echo "配置参数确认:"
echo "总 NPU 数量 (NUM_NPUS): $NUM_NPUS"
echo "每节点 NPU 数量 (NUM_NPUS_PER_NODE): $NUM_NPUS_PER_NODE"
echo "慢卡 Rank ID (SLOW_RANK_ID): $SLOW_RANK_ID"
echo "------------------------------------------------"

# --- 信号捕获 (清理机制) ---
# 当按下 Ctrl+C 时，执行 cleanup 函数
trap cleanup SIGINT

function cleanup() {
    echo -e "\n[!] 捕获到中断信号，正在清理进程..."
    # 杀掉当前进程组中的所有后台任务
    pkill -P $$ 
    # 针对性清理 python 进程
    pkill -9 python
    echo "[+] 测试已结束。"
    exit 0
}

# --- 1. 开启慢节点定界检测 (后台运行，输出到终端) ---
echo "[1/2] 启动 慢卡慢节点定界 systrace-failslow..."
systrace-failslow --detection-interval 10 --enable-slow-node &


sleep 10
echo "[2/2] 传入离线采集数据 (NPUs: $NUM_NPUS_PER_NODE, Slow Rank: $SLOW_RANK_ID)..."
# TODO： 如果NUM_NPUS=4，SLOW_RANK_ID=0，则从拷贝目录 ./data/dp4-rank0/ 下所有文件到/home/sysTrace/mspti/目录下 
# 构建源目录路径，例如 ./data/dp4-rank0
SOURCE_DIR="./data/dp${NUM_NPUS}-rank${SLOW_RANK_ID}"
TARGET_DIR="/home/sysTrace/mspti"
cp -r "$SOURCE_DIR"/. "$TARGET_DIR/"

# 等待systrace-failslow完成检测
sleep 120


echo "sysTrace测试完成"
cleanup
