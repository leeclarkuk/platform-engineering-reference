# Multi-cloud networking

Connecting AWS, Azure and GCP privately is possible. It is rarely the
first problem you should spend money on.

## When it is justified

* A named workload with data in two providers and a hard latency or
  residency constraint
* An acquisition you cannot migrate this year
* A partner-mandated path

## When it is not

* "Strategic flexibility"
* Active-active failover you have not tested
* Making the architecture diagram look complete

## Costs and failure modes you actually get

* Data transfer prices that dwarf compute
* Three DNS systems and a fourth overlapping split-horizon design
* MTU, ASN and overlapping CIDR fights
* Incidents that require three vendor support organisations
* A shared fate path that nobody wants to change

Prefer application-level integration over a global transit backbone.
If you still need packets, treat the interconnect as a product: owner,
SLO, failure-lab experiments 04 and 07, and a budget line.

Do not imply this is desirable. It is sometimes required. Those are
different statements.
