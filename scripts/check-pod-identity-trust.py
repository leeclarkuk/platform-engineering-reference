#!/usr/bin/env python3
"""Static semantic check for EKS Pod Identity IAM trust JSON.

Independent expected constants live only in this file. They are not read
from Terraform locals or from the policy under test.

Exit 0: policy matches the required trust contract.
Exit 1: policy does not match (used as the negative-fixture proof).
Exit 2: usage or parse error (must not be treated as a contract miss).
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

# Independent hardcoded contract. Do not load these from the policy file.
REQUIRED_SERVICE = "pods.eks.amazonaws.com"
REQUIRED_ACTIONS = frozenset({"sts:AssumeRole", "sts:TagSession"})


def fail_usage(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)


def as_list(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    return [value]


def check_policy(policy: Any) -> tuple[bool, str]:
    if not isinstance(policy, dict):
        return False, "policy root must be a JSON object"
    statements = policy.get("Statement")
    if not isinstance(statements, list) or len(statements) != 1:
        return False, "policy must contain exactly one Statement"
    statement = statements[0]
    if not isinstance(statement, dict):
        return False, "Statement[0] must be an object"

    principal = statement.get("Principal")
    if not isinstance(principal, dict):
        return False, "Principal must be an object"
    service = principal.get("Service")
    services = as_list(service)
    if services != [REQUIRED_SERVICE]:
        return False, (
            f"Principal.Service must be exactly {REQUIRED_SERVICE!r}, "
            f"got {service!r}"
        )

    action = statement.get("Action")
    actions = as_list(action)
    if not all(isinstance(item, str) for item in actions):
        return False, f"Action must be a string or list of strings, got {action!r}"
    got = frozenset(actions)
    if got != REQUIRED_ACTIONS or len(actions) != len(REQUIRED_ACTIONS):
        return False, (
            "Action must be exactly "
            f"{sorted(REQUIRED_ACTIONS)}, got {action!r}"
        )
    return True, "ok"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", required=True, help="Path to IAM trust policy JSON")
    args = parser.parse_args()

    try:
        with open(args.policy, encoding="utf-8") as handle:
            policy = json.load(handle)
    except OSError as exc:
        fail_usage(f"cannot read {args.policy}: {exc}")
    except json.JSONDecodeError as exc:
        fail_usage(f"invalid JSON in {args.policy}: {exc}")

    ok, detail = check_policy(policy)
    if ok:
        print(f"ok pod-identity trust: {args.policy}")
        return 0
    print(f"FAIL pod-identity trust: {args.policy}: {detail}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
