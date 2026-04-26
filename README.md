# Keryx Node & Miner Menu

Simple bash menu for installing and running a Keryx node and miner on a Linux GPU server.

## Features

- Install Keryx node from source
- Install Keryx miner from source
- Update node and miner without deleting node sync data
- Start node and miner together
- Stop node and miner cleanly
- Run node and miner in separate tmux sessions
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
3. Status
4. Start node and miner
5. Stop node and miner
6. Show logs
7. Update node and miner
8. Exit
```

`Update node and miner` rebuilds the latest code and restarts the tmux sessions. It does not delete the node data directory:

```text
/var/lib/keryx-node
```

`Start node and miner` starts both tmux sessions and immediately opens combined logs. Press `Ctrl+C` to leave logs without stopping the node or miner.

On the first `Start node and miner`, the script asks for the Keryx mining address and saves it to:

```text
/opt/keryx/wallet.txt
```

To change the saved address later, edit `/opt/keryx/wallet.txt` before starting the miner again.

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
