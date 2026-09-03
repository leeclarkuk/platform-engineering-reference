# infra/aws/network (Milestone 2)

Network root is VPC and subnets only.

Milestone 2 creates:
* one VPC
* public subnets
* an internet gateway and default route

Constraints:
* No Transit Gateway (TGW).
* No cluster, no Kubernetes objects.

pstack: aws/m2-foundations

