# Keryx Node & Miner Menu

Simple bash menu for installing and running a Keryx node and miner on a Linux GPU server.

## Features

- Install Keryx node from source
- Install Keryx miner from source
- Start node in a separate tmux session
- Start miner in a separate tmux session
- Show combined node and miner logs
- Show node/miner process status, sync status, and GPU usage
- Save a custom mining wallet for future restarts

## Requirements

- Linux server with root access
- NVIDIA driver already installed and working
- `nvidia-smi` should show the GPUs before mining
- Internet access for installing packages and cloning repositories

## Usage

Run this on the Linux GPU server as root:

```bash
curl -fsSL https://raw.githubusercontent.com/VaniaHilkovets/keryx-menu/main/keryx_menu.sh -o /root/keryx_menu.sh && chmod +x /root/keryx_menu.sh && bash /root/keryx_menu.sh
```

Menu:

```text
Keryx menu
1. Install node
2. Install miner
3. Start node
4. Start miner
5. Show logs
6. Status
7. Set wallet
8. Exit
```

On the first miner start, the script asks for the Keryx mining address and saves it to:

```text
/opt/keryx/wallet.txt
```

Use `Set wallet` to change the saved address later. Restart the miner after changing the wallet.

## tmux Sessions

The script starts the node and miner in separate tmux sessions:

```bash
tmux attach -t keryx-node
tmux attach -t keryx-miner
```

Detach from tmux without stopping the process:

```text
Ctrl+B, then D
```

## Logs

`Show logs` tails all main logs together:

```text
/var/log/keryx-runner/node.log
/var/log/keryx/keryx.log
/var/log/keryx-runner/miner.log
```

Exit logs with `Ctrl+C`. This does not stop the node or miner.

## Notes

The miner can show `0 hash/s` while the node is still syncing. Wait for the node to finish IBD/synchronization before judging mining performance.
