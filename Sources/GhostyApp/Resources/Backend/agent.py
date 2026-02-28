#!/usr/bin/env python3
"""Ghosty Agent — main entry point for the virtual assistant backend.

Usage: python3 agent.py "open Safari and search for cats"

Runs a LangGraph multi-agent graph:
  memory_load → supervisor → [web|system|files|gui] → ... → done → memory_save
"""

import os
import signal
import sys
import time

# Ensure sibling modules are importable regardless of working directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import state_bridge
from config import MAX_STEPS, MAX_TIMEOUT
from tools import applescript


# ── Process cleanup ──────────────────────────────────────────────────

_child_pids: set[int] = set()


def _cleanup_and_exit(signum=None, frame=None):
    """Kill all child processes and exit cleanly."""
    import subprocess

    # Kill any child processes we spawned
    for pid in list(_child_pids):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    # Also kill the entire process group to catch any stragglers
    try:
        os.killpg(os.getpgid(os.getpid()), signal.SIGTERM)
    except (ProcessLookupError, PermissionError, OSError):
        pass

    state_bridge.set_idle()
    sys.exit(0)


def _install_signal_handlers():
    """Install handlers so we clean up on SIGTERM, SIGINT, SIGHUP."""
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, _cleanup_and_exit)


# Patch subprocess.Popen to track child PIDs
_original_popen_init = None


def _tracking_popen_init(self, *args, **kwargs):
    _original_popen_init(self, *args, **kwargs)
    if self.pid:
        _child_pids.add(self.pid)


def _patch_subprocess_tracking():
    """Monkey-patch subprocess.Popen to track child PIDs for cleanup."""
    import subprocess
    global _original_popen_init
    _original_popen_init = subprocess.Popen.__init__
    subprocess.Popen.__init__ = _tracking_popen_init


# ── Context ──────────────────────────────────────────────────────────


def gather_context() -> dict:
    """Gather current macOS context for the supervisor."""
    ctx = {}
    try:
        ctx["frontmost_app"] = applescript.get_frontmost_app()
    except Exception:
        ctx["frontmost_app"] = "Unknown"
    try:
        ctx["running_apps"] = applescript.list_running_apps()
    except Exception:
        ctx["running_apps"] = []
    return ctx


# ── Main ─────────────────────────────────────────────────────────────


def run_agent(intent: str) -> str:
    """Main agent loop using LangGraph.

    Args:
        intent: User's natural language request.

    Returns:
        Final status message.
    """
    from graph.builder import build_graph

    start_time = time.time()

    # 1. Set working state
    state_bridge.set_working(f"Understanding: {intent}")

    # 2. Gather context
    context = gather_context()

    # 3. Build and run the graph
    graph = build_graph()

    initial_state = {
        "intent": intent,
        "messages": [],
        "current_agent": "supervisor",
        "agent_task": "",
        "agent_params": {},
        "steps_completed": [],
        "step_number": 0,
        "total_steps": MAX_STEPS,
        "user_preferences": {},
        "context": context,
        "error": None,
        "retry_count": 0,
        "final_message": "",
        "should_continue": True,
    }

    try:
        result = graph.invoke(
            initial_state,
            config={"recursion_limit": MAX_STEPS * 2},
        )

        final_message = result.get("final_message", "Task complete.")

        elapsed = time.time() - start_time
        if elapsed > MAX_TIMEOUT:
            final_message = f"Completed (took {elapsed:.0f}s, exceeded timeout)."

    except Exception as e:
        final_message = f"Failed: {e}"
        print(f"[agent] Graph execution error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)

    # 4. Set complete state
    state_bridge.set_complete(final_message)
    return final_message


def main() -> int:
    _install_signal_handlers()
    _patch_subprocess_tracking()

    intent = " ".join(sys.argv[1:]).strip()
    if not intent:
        print("Usage: python3 agent.py \"your intent here\"", file=sys.stderr)
        return 1

    print(f"[agent] Intent: {intent}")
    try:
        result = run_agent(intent)
        print(result)
    except (KeyboardInterrupt, SystemExit):
        _cleanup_and_exit()
    finally:
        state_bridge.set_idle()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
