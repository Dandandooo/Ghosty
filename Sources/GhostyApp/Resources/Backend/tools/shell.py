"""Safe CLI execution with command allowlist."""

import shlex
import subprocess

from config import SHELL_ALLOWLIST, SHELL_TIMEOUT


def run_command(command: str) -> str:
    """Execute a shell command if it's in the allowlist.

    Args:
        command: The command string to execute.

    Returns:
        stdout from the command.

    Raises:
        PermissionError: If the command's binary is not in the allowlist.
        RuntimeError: If the command fails.
    """
    parts = shlex.split(command)
    if not parts:
        raise ValueError("Empty command")

    binary = parts[0]
    if binary not in SHELL_ALLOWLIST:
        raise PermissionError(
            f"Command '{binary}' is not in the allowlist. "
            f"Allowed: {', '.join(sorted(SHELL_ALLOWLIST))}"
        )

    result = subprocess.run(
        parts,
        capture_output=True,
        text=True,
        timeout=SHELL_TIMEOUT,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"Command failed (exit {result.returncode}): {result.stderr.strip()}"
        )

    return result.stdout.strip()
