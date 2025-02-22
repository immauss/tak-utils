# Purpose
This pile of configs and scripts is for running a takserver in various container environments.
Initally on Docker with docker-compose
Then kubernets on Docker Desktop
Moving to AWS EKS

# ToDos:
x- how to get CoreConfig consistent and into container
x - update Coreconfig to point to actual database
x - get it to actually run
x - move the admin.loaded to /opt/tak/certs/files - This make the fact that the admin cert is loaded in the DB persistent . . .
x - CA_NAME, used in the start script for cert generation, should be an environment variable.
- remove bits from deployment not needed
  - Password - This is getting pulled from CoreConfig in both contianers. No need for secret mgmt.
  - ??
x - Fix load balancer so that ports are exposed correctly. (not the nodeport)
- Get datbase to replicate to other nodes ... run in master/slave ... with 3 replicas. 
- Why is start-db.sh so wonky .... wtf while true; do .... 
  - This and the 3 scripts it calls need to be optimized. It's a Freaking mess in there.
- takserver should be doing a pg_isready call to wait for the DB. 
  - needs to tool installed for that to work. :( 
    possible fix with total container image rebuild.
x- Need to add the following to configs. 
 x - CoreConfig.example.xml   
 x - UserAuthenticationFile.xml
 x - CoreConfig.xml          
 x - TAKIgniteConfig.xml          
 x - logging-restrictsize.xml
- Concern for multiple containers writing to xml files and causing corruption. 
  - No multiple replicas until this is resolve/answered.
  - Figure out why deleting a pod causes the configs to roll back ... 
-x Configs. 
  - some don't exist at starup ... the userauth.xml  (or whatever it si named) so need to create it in configs and link back to /opt/taks
