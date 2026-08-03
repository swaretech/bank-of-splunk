#!/usr/bin/env python3
"""Replay YAML user scenarios against the iOS Simulator via Appium."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import yaml
from appium import webdriver
from appium.options.ios import XCUITestOptions
from appium.webdriver.common.appiumby import AppiumBy
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CAPABILITIES = ROOT / "appium" / "capabilities.json"
DEFAULT_SCENARIOS_DIR = ROOT / "scenarios"

DEFAULT_SIMULATOR = os.environ.get("RUM_LOADGEN_SIMULATOR", "iPhone 17")
DEFAULT_BUNDLE_ID = os.environ.get("RUM_LOADGEN_BUNDLE_ID", "com.splunk.bankofsplunk")
DEFAULT_FLUSH_SECONDS = int(os.environ.get("RUM_LOADGEN_RUM_FLUSH_SECONDS", "30"))
DEFAULT_APPIUM_URL = os.environ.get("RUM_LOADGEN_APPIUM_URL", "http://127.0.0.1:4791")
DEFAULT_UDID = os.environ.get("RUM_LOADGEN_SIMULATOR_UDID", "")


def log(event: str, **fields) -> None:
    payload = {"event": event, **fields}
    print(json.dumps(payload), flush=True)


def load_capabilities(path: Path, simulator: str, udid: str) -> dict:
    with path.open(encoding="utf-8") as handle:
        caps = json.load(handle)

    caps["appium:deviceName"] = simulator
    if udid:
        caps["appium:udid"] = udid
    return caps


def load_scenario(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def find_element(driver, step: dict):
    if "accessibility_id" in step:
        return driver.find_element(AppiumBy.ACCESSIBILITY_ID, step["accessibility_id"])
    if "label" in step:
        return driver.find_element(AppiumBy.ACCESSIBILITY_LABEL, step["label"])
    if "name" in step:
        return driver.find_element(AppiumBy.NAME, step["name"])
    raise ValueError(f"Step missing selector: {step}")


def wait_for_element(driver, step: dict):
    timeout = float(step.get("timeout", 15))
    locator = None
    if "accessibility_id" in step:
        locator = (AppiumBy.ACCESSIBILITY_ID, step["accessibility_id"])
    elif "label" in step:
        locator = (AppiumBy.ACCESSIBILITY_LABEL, step["label"])
    elif "name" in step:
        locator = (AppiumBy.NAME, step["name"])
    else:
        raise ValueError(f"wait_for step missing selector: {step}")

    return WebDriverWait(driver, timeout).until(EC.presence_of_element_located(locator))


def rum_flush(driver, flush_seconds: int) -> None:
    """Background the app so Splunk RUM can export via background URLSession."""
    log("rum_flush_start", seconds=flush_seconds)
    try:
        driver.background_app(flush_seconds)
    except Exception as exc:
        log("rum_flush_fallback", error=str(exc))
        try:
            driver.execute_script("mobile: pressButton", {"name": "home"})
        except Exception:
            pass
        time.sleep(flush_seconds)
    log("rum_flush_complete", seconds=flush_seconds)


def execute_step(driver, step: dict, bundle_id: str, flush_seconds: int) -> None:
    action = step["action"]

    if action == "launch_app":
        driver.activate_app(bundle_id)
        time.sleep(2)
        return

    if action == "background_app":
        rum_flush(driver, int(step.get("seconds", flush_seconds)))
        return

    if action == "terminate_app":
        rum_flush(driver, flush_seconds)
        driver.terminate_app(bundle_id)
        return

    if action == "wait":
        time.sleep(float(step.get("seconds", 1)))
        return

    if action == "wait_for":
        wait_for_element(driver, step)
        return

    if action == "tap":
        element = find_element(driver, step)
        element.click()
        return

    if action == "type":
        element = find_element(driver, step)
        text = step.get("text", "")
        element.click()
        element.clear()
        element.send_keys(text)
        return

    raise ValueError(f"Unknown action: {action}")


def run_scenario(
    driver,
    scenario_path: Path,
    bundle_id: str,
    flush_seconds: int,
) -> None:
    scenario = load_scenario(scenario_path)
    name = scenario.get("name", scenario_path.stem)
    log("scenario_start", name=name, path=str(scenario_path))

    for index, step in enumerate(scenario.get("steps", []), start=1):
        try:
            execute_step(driver, step, bundle_id, flush_seconds)
        except Exception as exc:
            log(
                "step_failed",
                name=name,
                step=index,
                action=step.get("action"),
                error=str(exc),
            )
            raise

    log("scenario_complete", name=name)


def create_driver(appium_url: str, capabilities: dict) -> webdriver.Remote:
    options = XCUITestOptions()
    options.load_capabilities(capabilities)
    return webdriver.Remote(appium_url, options=options)


def discover_scenarios(scenarios_dir: Path, scenario_name: str | None) -> list[Path]:
    if scenario_name:
        path = scenarios_dir / f"{scenario_name}.yaml"
        if not path.exists():
            raise FileNotFoundError(f"Scenario not found: {path}")
        return [path]

    return sorted(scenarios_dir.glob("*.yaml"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenario",
        help="Scenario name without .yaml extension (default: run all scenarios)",
    )
    parser.add_argument(
        "--capabilities",
        type=Path,
        default=DEFAULT_CAPABILITIES,
        help="Path to Appium capabilities JSON",
    )
    parser.add_argument(
        "--scenarios-dir",
        type=Path,
        default=Path(os.environ.get("RUM_LOADGEN_SCENARIOS_DIR", DEFAULT_SCENARIOS_DIR)),
        help="Directory containing YAML scenarios",
    )
    parser.add_argument(
        "--simulator",
        default=DEFAULT_SIMULATOR,
        help="iOS Simulator device name",
    )
    parser.add_argument(
        "--bundle-id",
        default=DEFAULT_BUNDLE_ID,
        help="App bundle identifier",
    )
    parser.add_argument(
        "--appium-url",
        default=DEFAULT_APPIUM_URL,
        help="Appium server URL",
    )
    parser.add_argument(
        "--flush-seconds",
        type=int,
        default=DEFAULT_FLUSH_SECONDS,
        help="Seconds to wait after terminate_app for RUM export",
    )
    args = parser.parse_args()

    scenarios = discover_scenarios(args.scenarios_dir, args.scenario)
    if not scenarios:
        log("error", message=f"No scenarios found in {args.scenarios_dir}")
        return 1

    capabilities = load_capabilities(args.capabilities, args.simulator, DEFAULT_UDID)
    driver = None
    failures = 0

    try:
        driver = create_driver(args.appium_url, capabilities)
        log(
            "driver_ready",
            simulator=args.simulator,
            bundle_id=args.bundle_id,
            scenario_count=len(scenarios),
        )

        for scenario_path in scenarios:
            try:
                run_scenario(driver, scenario_path, args.bundle_id, args.flush_seconds)
            except Exception as exc:
                failures += 1
                log(
                    "scenario_failed",
                    name=scenario_path.stem,
                    error=str(exc),
                )
                try:
                    rum_flush(driver, args.flush_seconds)
                    driver.terminate_app(args.bundle_id)
                except Exception:
                    pass
    finally:
        if driver is not None:
            try:
                rum_flush(driver, args.flush_seconds)
            except Exception:
                pass
            driver.quit()

    if failures:
        log("replay_complete", status="failed", failures=failures)
        return 1

    log("replay_complete", status="success", scenarios=len(scenarios))
    return 0


if __name__ == "__main__":
    sys.exit(main())
