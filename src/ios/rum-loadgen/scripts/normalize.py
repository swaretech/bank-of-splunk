#!/usr/bin/env python3
"""Convert Appium Inspector Python exports into normalized YAML scenarios."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "scenarios"
DEFAULT_RAW_DIR = ROOT / "recordings" / "raw"

# DXA accessibility identifiers from DXAIdentifiers.swift
DXA_IDS = {
    "login-username",
    "login-password",
    "login-submit",
    "signup-submit",
    "signup-navigate",
    "signup-username",
    "signup-password",
    "signup-password-repeat",
    "signup-firstname",
    "signup-lastname",
    "signup-birthday",
    "deposit-open",
    "deposit-submit",
    "deposit-cancel",
    "deposit-amount",
    "payment-open",
    "payment-submit",
    "payment-cancel",
    "payment-amount",
    "logout-submit",
    "transactions-open",
}

ACCESSIBILITY_ID_PATTERN = re.compile(
    r"find_element\(AppiumBy\.ACCESSIBILITY_ID,\s*['\"]([^'\"]+)['\"]\)"
)
CLICK_PATTERN = re.compile(r"\.click\(\)")
SEND_KEYS_PATTERN = re.compile(
    r"find_element\([^)]+\)\.send_keys\(['\"]([^'\"]+)['\"]\)"
)
SLEEP_PATTERN = re.compile(r"time\.sleep\(([\d.]+)\)")
LABEL_PATTERN = re.compile(
    r"find_element\(AppiumBy\.ACCESSIBILITY_LABEL,\s*['\"]([^'\"]+)['\"]\)"
)


def parse_accessibility_steps(source: str) -> list[dict]:
    steps: list[dict] = []
    lines = source.splitlines()
    pending_id: str | None = None

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        sleep_match = SLEEP_PATTERN.search(stripped)
        if sleep_match:
            steps.append({"action": "wait", "seconds": float(sleep_match.group(1))})
            continue

        id_match = ACCESSIBILITY_ID_PATTERN.search(stripped)
        if id_match:
            pending_id = id_match.group(1)
            continue

        label_match = LABEL_PATTERN.search(stripped)
        if label_match:
            pending_id = None
            label = label_match.group(1)
            if CLICK_PATTERN.search(stripped):
                steps.append({"action": "tap", "label": label})
            continue

        if pending_id and CLICK_PATTERN.search(stripped):
            steps.append({"action": "tap", "accessibility_id": pending_id})
            pending_id = None
            continue

        send_keys_match = SEND_KEYS_PATTERN.search(stripped)
        if send_keys_match:
            text = send_keys_match.group(1)
            if pending_id:
                steps.append(
                    {
                        "action": "type",
                        "accessibility_id": pending_id,
                        "text": text,
                    }
                )
                pending_id = None
            continue

    return steps


def normalize_steps(steps: list[dict]) -> list[dict]:
    if not steps or steps[0].get("action") != "launch_app":
        steps.insert(0, {"action": "launch_app"})

    normalized: list[dict] = []
    for step in steps:
        if (
            normalized
            and step.get("action") == "wait"
            and normalized[-1].get("action") == "wait"
        ):
            normalized[-1]["seconds"] = normalized[-1].get("seconds", 0) + step.get(
                "seconds", 0
            )
            continue
        normalized.append(step)

    if normalized[-1].get("action") != "terminate_app":
        normalized.append({"action": "terminate_app"})
        normalized.append({"action": "wait", "seconds": 5})

    return normalized


def add_navigation_waits(steps: list[dict]) -> list[dict]:
    """Insert wait_for steps before taps on key navigation targets."""
    nav_targets = {
        "deposit-open",
        "payment-open",
        "logout-submit",
        "deposit-amount",
        "payment-amount",
        "login-submit",
    }
    result: list[dict] = []

    for step in steps:
        if step.get("action") == "tap":
            target = step.get("accessibility_id")
            if target in nav_targets:
                result.append(
                    {
                        "action": "wait_for",
                        "accessibility_id": target,
                        "timeout": 15,
                    }
                )
        result.append(step)

    return result


def infer_metadata(name: str) -> dict:
    metadata = {"synthetic": True}
    if "deposit" in name:
        metadata["flow"] = "deposit"
    elif "payment" in name:
        metadata["flow"] = "payment"
    elif "signup" in name:
        metadata["flow"] = "registration"
    else:
        metadata["flow"] = "authentication"
    return metadata


def convert_recording(raw_path: Path, output_dir: Path) -> Path:
    source = raw_path.read_text(encoding="utf-8")
    steps = parse_accessibility_steps(source)
    steps = normalize_steps(steps)
    steps = add_navigation_waits(steps)

    unknown_ids = {
        step["accessibility_id"]
        for step in steps
        if "accessibility_id" in step and step["accessibility_id"] not in DXA_IDS
    }
    if unknown_ids:
        print(
            f"warning: unknown accessibility IDs in {raw_path.name}: {sorted(unknown_ids)}",
            file=sys.stderr,
        )

    name = raw_path.stem.replace("_", "-")
    scenario = {
        "name": name,
        "description": f"Normalized from Appium Inspector recording {raw_path.name}",
        "metadata": infer_metadata(name),
        "steps": steps,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{name}.yaml"
    with output_path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(scenario, handle, sort_keys=False, default_flow_style=False)

    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording", type=Path, help="Raw Inspector Python export")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory for normalized YAML scenarios",
    )
    args = parser.parse_args()

    if not args.recording.exists():
        print(f"error: recording not found: {args.recording}", file=sys.stderr)
        return 1

    output_path = convert_recording(args.recording, args.output_dir)
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
