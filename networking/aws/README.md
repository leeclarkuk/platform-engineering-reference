# AWS networking

Hub-and-spoke with Transit Gateway. Centralised egress. Site-to-site
VPN on the hub, not on spokes. Route tables are explicit: default
association/propagation is off on the TGW module so routes cannot
silently appear.

Failure scenarios worth practising: TGW route removed, NAT exhaustion,
VPN down, resolver rule pointing at a dead inbound endpoint. See
`resilience/failure-lab`.
