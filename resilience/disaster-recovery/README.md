# Disaster recovery

DR is a tested RPO/RTO, not a second region on a slide.

For this platform:

* Git is the recovery artefact for desired state
* Terraform state needs a backup and a known restore path
* Container registries need replication or a rebuild pipeline that
  actually runs
* Data stores have their own DR, which is usually the expensive part

Do not claim multi-region Kubernetes until you have run experiment 03,
04, 07 and a datastore failover. Clusters are easy to clone. Data is not.
