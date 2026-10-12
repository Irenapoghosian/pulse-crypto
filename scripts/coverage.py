#!/usr/bin/env python3
"""Summarise code coverage from an .xcresult bundle.

Prints a Markdown table (for the GitHub job summary) and, with --badge, writes a
shields.io endpoint file. SwiftUI view files are left out of the badge number:
they are checked with previews rather than unit tests, and counting them would
hide how well the logic is tested. The table still lists every module.

Usage: coverage.py PATH.xcresult [--badge coverage.json] [--report report.json]
"""
import argparse
import json
import re
import subprocess
import sys

VIEW_FILE = re.compile(r"(View|Views|Components|Screen)\.swift$")


def load_report(xcresult, report_path):
    if report_path:
        with open(report_path) as handle:
            return json.load(handle)
    output = subprocess.check_output(["xcrun", "xccov", "view", "--report", "--json", xcresult])
    return json.loads(output)


def is_test_target(name):
    return name.endswith(".xctest") or "Tests" in name or "TestSupport" in name


def summarise(report):
    rows, logic_covered, logic_lines = [], 0, 0
    for target in report.get("targets", []):
        name = target.get("name", "")
        if is_test_target(name):
            continue
        covered, lines = 0, 0
        for source in target.get("files", []):
            covered += source.get("coveredLines", 0)
            lines += source.get("executableLines", 0)
            if not VIEW_FILE.search(source.get("name", "")):
                logic_covered += source.get("coveredLines", 0)
                logic_lines += source.get("executableLines", 0)
        if lines:
            module = re.sub(r"\.(o|framework|app|appex)$", "", name)
            rows.append((module, covered, lines))
    logic = logic_covered / logic_lines if logic_lines else 0.0
    return sorted(rows), logic


def badge_color(fraction):
    for limit, color in ((0.9, "brightgreen"), (0.75, "green"), (0.6, "yellowgreen"), (0.4, "yellow")):
        if fraction >= limit:
            return color
    return "orange"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("xcresult")
    parser.add_argument("--badge")
    parser.add_argument("--report", help="use an existing `xccov --json` report instead of running xccov")
    args = parser.parse_args()

    rows, logic = summarise(load_report(args.xcresult, args.report))

    print("### Code coverage\n")
    print("| Module | Lines | Coverage |")
    print("|---|---:|---:|")
    for module, covered, lines in rows:
        print(f"| {module} | {covered}/{lines} | {covered / lines:.0%} |")
    print(f"\n**Logic coverage (excluding SwiftUI view files): {logic:.0%}**")

    if args.badge:
        badge = {"schemaVersion": 1, "label": "coverage", "message": f"{logic:.0%}", "color": badge_color(logic)}
        with open(args.badge, "w") as handle:
            json.dump(badge, handle)
    return 0


if __name__ == "__main__":
    sys.exit(main())
