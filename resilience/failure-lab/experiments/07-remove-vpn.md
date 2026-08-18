# Remove a VPN path

**Hypothesis:** Hybrid dependencies die when the tunnel dies. Cloud
native dashboards stay green.

**Setup:** A lab workload that must reach an on-prem name via the hub
VPN. Do not do this on the production tunnel.

**Failure injected:** Disable the VPN connection or withdraw the
on-prem prefix.

**Expected behaviour:** Timeouts to on-prem. Cloud-to-cloud still
works. Help desks report "the app is down".

**Observed behaviour:** _Fill when run._

**Detection:** VPN tunnel state, BGP, user-path synthetic to the
hybrid dependency.

**Recovery:** Restore the tunnel. If both tunnels were active-active
only on a diagram, you will learn that here.

**MTTR:** _Fill when run._

**SLO impact:** Anything hybrid. Often the systems you cannot rewrite.

**Lessons:** Dual tunnels need dual tests.

**Permanent improvement:** Monitor tunnel _and_ a packet through it.
Tunnel up / prefix missing is a common lie.
