#!/usr/bin/env bash
# Static assertions for Transit Gateway routing intent.
# Runs without AWS credentials.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "ok  $desc"
  else
    echo "FAIL $desc"
    fail=1
  fi
}

tgw="$root/terraform/modules/aws/transit-gateway/main.tf"
vpc="$root/terraform/modules/aws/vpc/main.tf"
net="$root/terraform/aws/network/main.tf"
wl="$root/terraform/aws/workload/main.tf"

check "TGW default association disabled" \
  grep -q 'default_route_table_association = "disable"' "$tgw"
check "TGW default propagation disabled" \
  grep -q 'default_route_table_propagation = "disable"' "$tgw"
check "attachments do not use the default TGW route table" \
  grep -q 'transit_gateway_default_route_table_association = false' "$vpc"
check "network stack does not enable a TGW default route" \
  grep -qE 'allow_default_route[[:space:]]*=[[:space:]]*false' "$net"
check "workload stack does not send 0.0.0.0/0 to the TGW" \
  grep -qE 'allow_default_route_to_tgw[[:space:]]*=[[:space:]]*false' "$wl"
check "hub VPC routes the workload CIDR to the TGW" \
  grep -qE 'transit_gateway_routes[[:space:]]*=[[:space:]]*\[var.workload_cidr\]' "$net"
check "workload VPC routes the hub CIDR to the TGW" \
  grep -qE 'transit_gateway_routes[[:space:]]*=[[:space:]]*\[var.network_hub_cidr\]' "$wl"

if grep -n 'transit_gateway_id' "$net" | grep -q '0.0.0.0/0'; then
  echo "FAIL network stack appears to send a default route to the TGW"
  fail=1
else
  echo "ok  no default route toward TGW in the network stack"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "route assertions failed"
  exit 1
fi
echo "route assertions OK"
