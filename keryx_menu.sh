#!/usr/bin/env bash
set -u

NODE_REPO="https://github.com/Keryx-Labs/keryx-node.git"
MINER_REPO="https://github.com/Keryx-Labs/keryx-miner.git"

ROOT="/opt/keryx"
SRC_NODE="$ROOT/keryx-node"
SRC_MINER="$ROOT/keryx-miner"
BIN="$ROOT/bin"
NODE_APPDIR="/var/lib/keryx-node"
NODE_LOGDIR="/var/log/keryx"
RUNNER_LOGDIR="/var/log/keryx-runner"
WALLET_FILE="$ROOT/wallet.txt"
RPC_HOST="127.0.0.1"
RPC_PORT="22110"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo bash keryx_menu.sh"
    exit 1
  fi
}

ensure_dirs() {
  mkdir -p "$ROOT" "$BIN" "$NODE_APPDIR" "$NODE_LOGDIR" "$RUNNER_LOGDIR"
}

install_deps() {
  require_root
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y \
      build-essential pkg-config libssl-dev protobuf-compiler \
      clang cmake git curl tmux python3 ca-certificates ocl-icd-opencl-dev
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y \
      gcc gcc-c++ make pkgconf-pkg-config openssl-devel protobuf-compiler \
      clang cmake git curl tmux python3 ocl-icd-devel
  else
    echo "No apt-get/dnf found. Install build deps manually."
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
  fi

  # shellcheck disable=SC1091
  [ -f /root/.cargo/env ] && source /root/.cargo/env
}

get_wallet() {
  ensure_dirs
  if [ -s "$WALLET_FILE" ]; then
    cat "$WALLET_FILE"
    return
  fi

  while true; do
    printf "Enter Keryx mining address: " >&2
    read -r wallet
    if [ -n "$wallet" ]; then
      break
    fi
    echo "Wallet address cannot be empty." >&2
  done
  printf "%s\n" "$wallet" > "$WALLET_FILE"
  chmod 600 "$WALLET_FILE"
  printf "%s\n" "$wallet"
}

clone_or_update() {
  local repo="$1"
  local dst="$2"

  if [ -d "$dst/.git" ]; then
    git -C "$dst" fetch --all --prune
    git -C "$dst" pull --ff-only || true
  else
    git clone "$repo" "$dst"
  fi
}

install_node() {
  set -e
  require_root
  install_deps
  ensure_dirs
  clone_or_update "$NODE_REPO" "$SRC_NODE"
  (
    cd "$SRC_NODE"
    ulimit -n 1048576 || true
    cargo build --release
  )
  cp "$SRC_NODE/target/release/keryxd" "$BIN/keryxd"
  chmod +x "$BIN/keryxd"
  echo
  echo "Node installed."
  set +e
}

build_node_only() {
  set -e
  require_root
  install_deps
  ensure_dirs
  clone_or_update "$NODE_REPO" "$SRC_NODE"
  (
    cd "$SRC_NODE"
    ulimit -n 1048576 || true
    cargo build --release
  )
  cp "$SRC_NODE/target/release/keryxd" "$BIN/keryxd"
  chmod +x "$BIN/keryxd"
  set +e
}

install_miner() {
  set -e
  require_root
  install_deps
  ensure_dirs
  clone_or_update "$MINER_REPO" "$SRC_MINER"
  (
    cd "$SRC_MINER"
    ulimit -n 1048576 || true
    cargo build --release
  )
  cp "$SRC_MINER/target/release/keryx-miner" "$BIN/keryx-miner"
  [ -f "$SRC_MINER/target/release/libkeryxcuda.so" ] && cp "$SRC_MINER/target/release/libkeryxcuda.so" "$BIN/"
  [ -f "$SRC_MINER/target/release/libkeryxopencl.so" ] && cp "$SRC_MINER/target/release/libkeryxopencl.so" "$BIN/"
  chmod +x "$BIN/keryx-miner"
  echo
  echo "Miner installed."
  set +e
}

build_miner_only() {
  set -e
  require_root
  install_deps
  ensure_dirs
  clone_or_update "$MINER_REPO" "$SRC_MINER"
  (
    cd "$SRC_MINER"
    ulimit -n 1048576 || true
    cargo build --release
  )
  cp "$SRC_MINER/target/release/keryx-miner" "$BIN/keryx-miner"
  [ -f "$SRC_MINER/target/release/libkeryxcuda.so" ] && cp "$SRC_MINER/target/release/libkeryxcuda.so" "$BIN/"
  [ -f "$SRC_MINER/target/release/libkeryxopencl.so" ] && cp "$SRC_MINER/target/release/libkeryxopencl.so" "$BIN/"
  chmod +x "$BIN/keryx-miner"
  set +e
}

start_node() {
  require_root
  ensure_dirs

  if [ ! -x "$BIN/keryxd" ]; then
    echo "Node is not installed yet."
    return
  fi

  if tmux has-session -t keryx-node 2>/dev/null; then
    echo "Node already running. Attach with: tmux attach -t keryx-node"
    return
  fi

  tmux new-session -d -s keryx-node \
    "ulimit -n 1048576 || true; $BIN/keryxd --appdir $NODE_APPDIR --logdir $NODE_LOGDIR --rpclisten=$RPC_HOST:$RPC_PORT --disable-upnp --yes 2>&1 | tee -a $RUNNER_LOGDIR/node.log"
  echo "Node started. Attach with: tmux attach -t keryx-node"
}

start_miner() {
  require_root
  ensure_dirs

  if [ ! -x "$BIN/keryx-miner" ]; then
    echo "Miner is not installed yet."
    return
  fi

  if tmux has-session -t keryx-miner 2>/dev/null; then
    echo "Miner already running. Attach with: tmux attach -t keryx-miner"
    return
  fi

  local wallet
  wallet="$(get_wallet)"

  tmux new-session -d -s keryx-miner \
    "ulimit -n 1048576 || true; cd $BIN; RUST_LOG=info $BIN/keryx-miner --mining-address '$wallet' --keryxd-address $RPC_HOST --port $RPC_PORT --threads 0 --cuda-workload 64 2>&1 | tee -a $RUNNER_LOGDIR/miner.log"
  echo "Miner started. Attach with: tmux attach -t keryx-miner"
}

start_node_and_miner() {
  require_root
  ensure_dirs

  start_node
  start_miner

  echo
  echo "Opening combined logs. Press Ctrl+C to leave logs; node and miner will keep running in tmux."
  show_logs
}

stop_node_and_miner() {
  require_root
  echo "Stopping Keryx node and miner..."
  tmux kill-session -t keryx-miner 2>/dev/null || true
  tmux kill-session -t keryx-node 2>/dev/null || true
  sleep 2
  pkill -x keryx-miner 2>/dev/null || true
  pkill -x keryxd 2>/dev/null || true
  echo "Stopped Keryx node and miner."
}

update_node_and_miner() {
  set -e
  require_root
  ensure_dirs

  echo
  echo "Updating Keryx node and miner."
  echo "Node data directory will be kept unchanged: $NODE_APPDIR"
  echo

  stop_node_and_miner
  build_node_only
  build_miner_only
  start_node_and_miner

  echo
  echo "Update complete. Existing node sync data was not deleted."
  set +e
}

show_logs() {
  require_root
  ensure_dirs
  touch "$RUNNER_LOGDIR/node.log" "$NODE_LOGDIR/keryx.log" "$RUNNER_LOGDIR/miner.log"
  tail -F "$RUNNER_LOGDIR/node.log" "$NODE_LOGDIR/keryx.log" "$RUNNER_LOGDIR/miner.log"
}

show_status() {
  require_root
  ensure_dirs
  shopt -s nullglob

  echo
  echo "Keryx status"
  echo "------------"

  if tmux has-session -t keryx-node 2>/dev/null; then
    echo "Node tmux:   running (keryx-node)"
  else
    echo "Node tmux:   not running"
  fi

  if pgrep -x keryxd >/dev/null 2>&1; then
    echo "Node proc:   running"
  else
    echo "Node proc:   not running"
  fi

  if tmux has-session -t keryx-miner 2>/dev/null; then
    echo "Miner tmux:  running (keryx-miner)"
  else
    echo "Miner tmux:  not running"
  fi

  if pgrep -x keryx-miner >/dev/null 2>&1; then
    echo "Miner proc:  running"
  else
    echo "Miner proc:  not running"
  fi

  echo
  echo "Sync:"
  local sync_line
  local node_logs=("$RUNNER_LOGDIR"/node.log "$NODE_LOGDIR"/*.log)
  sync_line="$(grep -hEi 'IBD|sync|Processed [0-9]+ (blocks|headers)' "${node_logs[@]}" 2>/dev/null | tail -n 1)"
  if [ -n "$sync_line" ]; then
    echo "$sync_line"
  else
    echo "No sync info found yet. Node logs checked:"
    printf "  %s\n" "${node_logs[@]}"
  fi

  echo
  echo "Last miner line:"
  local miner_line
  local miner_logs=("$RUNNER_LOGDIR"/miner.log)
  miner_line="$(tail -n 300 "${miner_logs[@]}" 2>/dev/null | grep -Ei 'hash/s|Spawned Thread|Workers stalled|Keryxd is not synced|Registered for new template|accepted|submitted|CUDA worker|Plugins found' | tail -n 1)"
  if [ -n "$miner_line" ]; then
    echo "$miner_line"
  else
    echo "No miner info found yet. Miner logs checked:"
    printf "  %s\n" "${miner_logs[@]}"
  fi

  if command -v nvidia-smi >/dev/null 2>&1; then
    echo
    echo "GPU:"
    nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader 2>/dev/null || true
  fi
}

main_menu() {
  require_root
  while true; do
    cat <<'MENU'

Keryx menu
1. Install node
2. Install miner
3. Status
4. Start node and miner
5. Stop node and miner
6. Show logs
7. Update node and miner
8. Exit
MENU
    printf "Choose: "
    read -r choice
    case "$choice" in
      1) install_node ;;
      2) install_miner ;;
      3) show_status ;;
      4) start_node_and_miner ;;
      5) stop_node_and_miner ;;
      6) show_logs ;;
      7) update_node_and_miner ;;
      8) exit 0 ;;
      *) echo "Unknown choice." ;;
    esac
  done
}

main_menu
