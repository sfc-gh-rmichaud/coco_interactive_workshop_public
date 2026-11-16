#!/usr/bin/env python3
"""Safe local practice setup and deterministic checks; no account/network access."""
from __future__ import annotations

import argparse
from contextlib import closing
import csv
import io
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
LABS = {"81", "82", "83", "84", "85", "86", "92", "94"}
MARKER = "coco-extension-practice.json"
SCHEMA = {
    "type": "object", "required": ["release_id", "decision", "findings"], "additionalProperties": False,
    "properties": {
        "release_id": {"type": "string"}, "decision": {"enum": ["READY", "BLOCKED"]},
        "findings": {"type": "array", "items": {
            "type": "object", "required": ["rule_id", "source", "evidence"], "additionalProperties": False,
            "properties": {key: {"type": "string", "minLength": 1} for key in ("rule_id", "source", "evidence")}}}}}


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def initialize(destination, lab):
    if lab not in LABS:
        raise ValueError("This lab does not use the practice kit")
    destination = Path(destination).expanduser().absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError("Destination already exists; choose a new path. Nothing overwritten.")
    if not destination.parent.is_dir():
        raise ValueError("Parent directory must already exist")
    fixture = json.loads((ROOT / "fixtures.json").read_text(encoding="utf-8"))
    destination.mkdir()
    dump(destination / MARKER, {"format": 1, "lab": lab})
    for name in ("fixtures.json", "server.py", "release-policy.md"):
        shutil.copy2(ROOT / name, destination / name)
    shutil.copytree(ROOT / "templates", destination / "templates")
    dump(destination / "release.json", fixture["release"])
    dump(destination / "checks.json", fixture["checks"])
    dump(destination / "ops-evidence.json", fixture["ops"])
    dump(destination / "review-schema.json", SCHEMA)
    dump(destination / "mcp-config.json", {"mcpServers": {"ws-release-desk": {
        "type": "stdio", "command": sys.executable,
        "args": [str(destination / "server.py")], "cwd": str(destination)}}})
    for name in ("orders", "events"):
        with (destination / (name + ".csv")).open("w", newline="", encoding="utf-8") as output:
            writer = csv.DictWriter(output, fieldnames=list(fixture[name][0]))
            writer.writeheader()
            writer.writerows(fixture[name])
    (destination / "bad-query.sql").write_text(
        "-- Deliberately wrong: event fanout and NULL exclusion. Offline fixture only.\n"
        "SELECT COUNT(*) AS order_count, SUM(o.amount) AS revenue\n"
        "FROM orders o JOIN events e ON o.order_id = e.order_id\n"
        "WHERE o.status <> 'CANCELLED';\n", encoding="utf-8")
    (destination / "sql-contract.md").write_text(
        "# Offline synthetic SQL contract\n\norders: one row per order_id; amount is whole dollars.\n"
        "events: one row per event_id; multiple events per order are valid.\n"
        "Include every order except status CANCELLED, including NULL status and orders with no events.\n"
        "Return one row: order_count, revenue (sum of amount once per included order).\n"
        "For no eligible orders return order_count=0 and revenue=0, not NULL.\n"
        "Use SELECT or WITH only, on orders/events; no DDL, DML or filesystem operations.\n"
        "The local SQLite checker is not a Snowflake compilation test.\n", encoding="utf-8")
    (destination / "batch-review.txt").write_text(
        "Review only this synthetic practice directory. Read release-policy.md, release.json, "
        "checks.json and review-schema.json with the read tool. No SQL, network, shell, edits or deployment. "
        "Review REL-204 under the policy. Return only one JSON object matching the schema, without "
        "markdown fences or extra prose. Cite the source filename and evidence in each finding.\n", encoding="utf-8")
    return destination


def practice_root(destination):
    root = Path(destination).expanduser().resolve(strict=True)
    marker = root / MARKER
    if marker.is_symlink() or not marker.is_file():
        raise ValueError("Not a marked practice directory")
    data = json.loads(marker.read_text(encoding="utf-8"))
    if data.get("format") != 1 or data.get("lab") not in LABS:
        raise ValueError("Unknown practice marker")
    return root


def local_file(root, relative):
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Expected a relative path inside the practice directory")
    root = root.resolve(strict=True)
    path = root
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError("Symlink inputs are not supported")
    path.resolve(strict=True).relative_to(root)
    return path


def verify_report(root, relative):
    release = json.loads(local_file(root, "release.json").read_text(encoding="utf-8"))
    checks = json.loads(local_file(root, "checks.json").read_text(encoding="utf-8"))
    original = json.loads((ROOT / "fixtures.json").read_text(encoding="utf-8"))
    if release != original["release"] or checks != original["checks"]:
        raise ValueError("Oracle checks the original fixture only; restore original evidence first")
    report = json.loads(local_file(root, relative).read_text(encoding="utf-8"))
    if not isinstance(report, dict) or set(report) != {"release_id", "decision", "findings"}:
        raise ValueError("Report must contain exactly release_id, decision, findings")
    expected = {}
    for check in checks:
        if check["required"] and check["status"] == "FAIL":
            expected["REQUIRED_CHECK_FAILED"] = "checks.json"
        elif check["required"] and check["status"] != "PASS":
            expected["REQUIRED_CHECK_INCOMPLETE"] = "checks.json"
    if not release["rollback_reference"]:
        expected["ROLLBACK_MISSING"] = "release.json"
    if report["release_id"] != release["release_id"] or report["decision"] != ("BLOCKED" if expected else "READY"):
        raise ValueError("Wrong release ID or decision")
    findings = report["findings"]
    if not isinstance(findings, list):
        raise ValueError("findings must be a list")
    seen = set()
    for finding in findings:
        if not isinstance(finding, dict) or set(finding) != {"rule_id", "source", "evidence"}:
            raise ValueError("Each finding needs exactly rule_id, source, evidence")
        if any(not isinstance(value, str) or not value.strip() for value in finding.values()):
            raise ValueError("Finding values must be nonempty strings")
        rule = finding["rule_id"]
        if rule in seen or rule not in expected or finding["source"] != expected[rule]:
            raise ValueError("Duplicate/unknown rule or incorrect source")
        seen.add(rule)
    if seen != set(expected):
        raise ValueError("Missing policy blockers")
    return {"status": "PASS", "decision": report["decision"], "rules_checked": sorted(seen),
            "limitation": "Shape and rule coverage only; inspect prose and invocation traces separately"}


def smoke_mcp(root):
    script = local_file(root, "server.py")
    fixture = json.loads(local_file(root, "fixtures.json").read_text(encoding="utf-8"))
    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "workshop-check", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "get_ticket", "arguments": {"ticket_id": "WS-102"}}},
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "get_release", "arguments": {"release_id": "REL-204"}}},
        {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "get_ticket", "arguments": {"ticket_id": "WS-999"}}},
        {"jsonrpc": "2.0", "id": 6, "method": "tools/call", "params": {"name": "get_ticket", "arguments": {"ticket_id": 102}}},
        {"jsonrpc": "2.0", "id": 7, "method": "tools/call", "params": {"name": "close_ticket", "arguments": {"ticket_id": "WS-102"}}},
    ]
    before = local_file(root, "fixtures.json").read_bytes()
    completed = subprocess.run([sys.executable, str(script)], input="\n".join(json.dumps(item) for item in requests) + "\nnot-json\n",
                               text=True, capture_output=True, timeout=10, cwd=root)
    if completed.returncode != 0:
        raise ValueError("MCP subprocess failed: " + completed.stderr[:500])
    responses = [json.loads(line) for line in completed.stdout.splitlines()]
    if len(responses) != 8:
        raise ValueError("Unexpected protocol response count or stdout contamination")
    by_id = {response["id"]: response for response in responses}
    if by_id[1]["result"]["protocolVersion"] != "2025-06-18":
        raise ValueError("Protocol negotiation failed")
    if {tool["name"] for tool in by_id[2]["result"]["tools"]} != {"get_ticket", "get_release"}:
        raise ValueError("Unexpected tool surface")
    ticket = json.loads(by_id[3]["result"]["content"][0]["text"])
    if ticket["ticket"] != fixture["tickets"][1] or ticket["source"] != "fixtures.json":
        raise ValueError("Incorrect ticket response")
    release = json.loads(by_id[4]["result"]["content"][0]["text"])
    if release["release"] != fixture["release"] or release["checks"] != fixture["checks"]:
        raise ValueError("Incorrect release response")
    if json.loads(by_id[5]["result"]["content"][0]["text"])["found"]:
        raise ValueError("Unknown ticket unexpectedly found")
    if any(by_id[index]["error"]["code"] != -32602 for index in (6, 7)) or by_id[None]["error"]["code"] != -32700:
        raise ValueError("Invalid requests were not rejected")
    if local_file(root, "fixtures.json").read_bytes() != before:
        raise ValueError("Read-only calls changed fixture")
    return {"status": "PASS", "scope": "MCP subprocess protocol, not CoCo integration", "responses_checked": len(responses)}


def sql_check(root, relative):
    query = local_file(root, relative).read_text(encoding="utf-8")
    orders = list(csv.DictReader(io.StringIO(local_file(root, "orders.csv").read_text(encoding="utf-8"))))
    events = list(csv.DictReader(io.StringIO(local_file(root, "events.csv").read_text(encoding="utf-8"))))
    cases = [("baseline", orders, events),
             ("duplicate-event", orders, events + [{"event_id": "EX", "order_id": "O1"}]),
             ("same-amount-order", orders + [{"order_id": "OX", "amount": "100", "status": "SHIPPED"}], events),
             ("no-eligible-orders", [{"order_id": "OC", "amount": "20", "status": "CANCELLED"}], [])]
    output = []
    for name, case_orders, case_events in cases:
        eligible = [row for row in case_orders if row["status"] != "CANCELLED"]
        expected = (len(eligible), sum(int(row["amount"]) for row in eligible))
        with closing(sqlite3.connect(":memory:", isolation_level=None)) as connection:
            connection.execute("CREATE TABLE orders(order_id TEXT, amount INTEGER, status TEXT)")
            connection.execute("CREATE TABLE events(event_id TEXT, order_id TEXT)")
            connection.executemany("INSERT INTO orders VALUES (?, ?, ?)", [(row["order_id"], int(row["amount"]), row["status"] or None) for row in case_orders])
            connection.executemany("INSERT INTO events VALUES (?, ?)", [(row["event_id"], row["order_id"]) for row in case_events])
            # Deny all writes, attachment, pragmas and non-fixture reads; bound work.
            allowed = {sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ, sqlite3.SQLITE_FUNCTION}
            def authorize(action, arg1, arg2, database, trigger):
                if action == sqlite3.SQLITE_READ and arg1 not in {"orders", "events"}:
                    return sqlite3.SQLITE_DENY
                if action == sqlite3.SQLITE_FUNCTION and arg2 not in {"count", "sum", "coalesce", "ifnull"}:
                    return sqlite3.SQLITE_DENY
                return sqlite3.SQLITE_OK if action in allowed else sqlite3.SQLITE_DENY
            connection.set_authorizer(authorize)
            remaining = [1000]
            def progress():
                remaining[0] -= 1
                return int(remaining[0] <= 0)
            connection.set_progress_handler(progress, 1000)
            cursor = connection.execute(query)
            columns = [description[0] for description in cursor.description or []]
            rows = cursor.fetchmany(2)
        actual = tuple(rows[0]) if len(rows) == 1 else None
        passed = columns == ["order_count", "revenue"] and actual == expected
        output.append({"case": name, "expected": list(expected), "actual": list(actual) if actual is not None else None, "pass": passed})
    return {"status": "PASS" if all(row["pass"] for row in output) else "FAIL", "scope": "Offline SQLite semantics; not Snowflake compilation", "cases": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    setup = sub.add_parser("init")
    setup.add_argument("--lab", required=True, choices=sorted(LABS))
    setup.add_argument("--dest", required=True)
    for name in ("verify", "smoke-mcp", "sql-check"):
        command = sub.add_parser(name)
        command.add_argument("--dest", required=True)
        if name == "verify":
            command.add_argument("--report", required=True)
        if name == "sql-check":
            command.add_argument("--query", required=True)
    args = parser.parse_args()
    try:
        if args.command == "init":
            root = initialize(args.dest, args.lab)
            result = {"status": "CREATED", "directory": str(root), "python": sys.executable,
                      "note": "No extensions registered; no account/network access"}
        else:
            root = practice_root(args.dest)
            result = (verify_report(root, args.report) if args.command == "verify" else
                      smoke_mcp(root) if args.command == "smoke-mcp" else sql_check(root, args.query))
        print(json.dumps(result, indent=2))
        return 1 if result["status"] == "FAIL" else 0
    except (ValueError, OSError, sqlite3.Error, subprocess.SubprocessError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
