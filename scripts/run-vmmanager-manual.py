#!/usr/bin/env python3
"""Start QEMU via VMManager and keep it running for manual SSH testing."""

import argparse
import logging
import signal
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tests.lib.vm_manager import VMManager  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Boot VM with VMManager and keep it running for manual checks"
    )
    parser.add_argument(
        "--qcow2",
        default="output/debian-a11ydevs.qcow2",
        help="Path to QCOW2 image (default: output/debian-a11ydevs.qcow2)",
    )
    parser.add_argument(
        "--ssh-port",
        type=int,
        default=2222,
        help="Host port forwarded to guest SSH (default: 2222)",
    )
    parser.add_argument(
        "--vm-memory",
        type=int,
        default=1536,
        help="Memory in MB (default: 1536)",
    )
    parser.add_argument(
        "--vm-cpus",
        type=int,
        default=1,
        help="Number of vCPUs (default: 1)",
    )
    parser.add_argument(
        "--ssh-timeout",
        type=int,
        default=180,
        help="Seconds to wait for SSH readiness (default: 180)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    qcow2_path = REPO_ROOT / args.qcow2
    if not qcow2_path.exists():
        print(f"QCOW2 not found: {qcow2_path}")
        return 1

    vm = VMManager()
    keep_running = True

    def _handle_signal(signum, frame):
        nonlocal keep_running
        keep_running = False

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    try:
        print(
            f">> Boot via VMManager.boot() qcow2={qcow2_path} "
            f"port={args.ssh_port} mem={args.vm_memory} cpus={args.vm_cpus}"
        )
        vm.boot(
            str(qcow2_path),
            ssh_port=args.ssh_port,
            memory=args.vm_memory,
            cpus=args.vm_cpus,
        )

        print(f">> Waiting for SSH (timeout={args.ssh_timeout}s)")
        vm.wait_ssh_ready(timeout=args.ssh_timeout)

        print("\n>> VM is up and SSH is ready.")
        print(
            f">> Test manually with: ssh -p {args.ssh_port} "
            "a11ydevs@127.0.0.1"
        )
        print(
            ">> Use Ctrl+C in this terminal when you want to stop the VM.\n"
        )

        while keep_running:
            time.sleep(1)

        return 0
    finally:
        print(">> Shutting down VM...")
        vm.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
