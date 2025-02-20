ToDos:
- how to get CoreConfig consistent and into container
- update Coreconfig to point to actual database
- get it to actually run
- move the admin.loaded to /opt/tak/certs/files - This make the fact that the admin cert is loaded in the DB persistent . . .
- CA_NAME, used in the start script for cert generation, should be an environment variable.
- remove bits from deployment not needed
  - Password - This is getting pulled from CoreConfig in both contianers. No need for secret mgmt.
  - ??
- Fix load balancer so that ports are exposed correctly. (not the nodeport)
- Get datbase to replicate to other nodes ... run in master/slave ... with 3 replicas. 
- Why is start-db.sh so wonky .... wtf while true; do .... 

