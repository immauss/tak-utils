# Purpose
This pile of configs and scripts is for running a takserver in various container environments.
Initally on Docker with docker-compose
Then kubernets on Docker Desktop
Moving to AWS EKS

The current build has not been tested with docker-compose as the primary focus has been on k8s. It should work, but will require some tweaks to the docker-compose.yaml.

# Concepts
You need only edit the docker-compose.yaml or deployment.yaml and set the the following:
- STATE="NSS"
- CITY="NSC"
- ORGANIZATION="NSO"
- ORGANIZATIONAL_UNIT="NSOU"

These are used to create the self signed certs used by TAK. 

- For Kubernetes, you need to copy the configs into what ever you choose to use for storage. This should be done in the future with a "sidecar" container, but is not there yet. 
- Using docker compose, you can put the configs in the appropirate local directory.

# ToDos:
[ ] - use password from env to replace value in CoreConfig.xml for DB password so it can stored as a secret.
[ ] - sidecar to load the configs in the storage.
[ ] - Build from scratch instead of using image from ironbank
x- how to get CoreConfig consistent and into container
x - update Coreconfig to point to actual database
x - get it to actually run
x - move the admin.loaded to /opt/tak/certs/files - This make the fact that the admin cert is loaded in the DB persistent . . .
x - CA_NAME, used in the start script for cert generation, should be an environment variable.
x remove bits from deployment not needed
  x Password - This is getting pulled from CoreConfig in both contianers. No need for secret mgmt.
  - ??
x - Fix load balancer so that ports are exposed correctly. (not the nodeport)
- Get datbase to replicate to other nodes ... run in master/slave ... with 3 replicas. 
x Why is start-db.sh so wonky .... wtf while true; do .... 
  x This and the 3 scripts it calls need to be optimized. It's a Freaking mess in there.
x takserver should be doing a pg_isready call to wait for the DB. 
  x needs to tool installed for that to work. :( 
    possible fix with total container image rebuild.
x- Need to add the following to configs. 
 x - CoreConfig.example.xml   
 x - UserAuthenticationFile.xml
 x - CoreConfig.xml          
 x - TAKIgniteConfig.xml          
 x - logging-restrictsize.xml
x Concern for multiple containers writing to xml files and causing corruption. 
  x No multiple replicas until this is resolve/answered.
  x Figure out why deleting a pod causes the configs to roll back ... 
-x Configs. 
  x some don't exist at starup ... the userauth.xml  (or whatever it si named) so need to create it in configs and link back to /opt/taks
