#!/usr/bin/env python3
"""Run the PickPocketTracker Lua test suite against a stubbed WoW client.

Each tests/test_*.lua file runs in its own fresh Lua state, so one test file
cannot leak globals or SavedVariables into another. The Lua side reports
failures by setting the global TEST_FAILURES, which this script turns into an
exit status.

Requires lupa (a Lua runtime embedded in Python):

    python3 -m venv .venv && .venv/bin/pip install lupa
    .venv/bin/python tests/run_tests.py

Run a subset by passing name fragments:  run_tests.py items coins
"""
import pathlib
import sys

try:
    import lupa
except ImportError:
    sys.exit("lupa is not installed. See the docstring above, or tests/README.md.")

TESTS_DIR = pathlib.Path(__file__).resolve().parent
ADDON_DIR = TESTS_DIR.parent


def discover(filters):
    files = sorted(TESTS_DIR.glob("test_*.lua"))
    if filters:
        files = [f for f in files if any(x in f.name for x in filters)]
    return files


def run(path):
    """Execute one test file in a fresh Lua state. Returns the failure count."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ADDON_DIR = str(ADDON_DIR)
    lua.globals().TESTS_DIR = str(TESTS_DIR)
    lua.globals().TEST_FAILURES = 0

    print("\n=== %s ===" % path.name, flush=True)
    try:
        lua.execute(path.read_text(encoding="utf-8"))
    except lupa.LuaError as exc:
        print("  ERROR  %s raised:\n    %s" % (path.name, exc))
        return 1

    failures = lua.globals().TEST_FAILURES
    return int(failures or 0)


def main():
    files = discover(sys.argv[1:])
    if not files:
        sys.exit("no test files matched")

    total = 0
    for path in files:
        total += run(path)

    print("\n" + "-" * 56)
    if total:
        print("FAILED - %d failing assertion(s) across %d file(s)" % (total, len(files)))
    else:
        print("OK - all assertions passed across %d file(s)" % len(files))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
