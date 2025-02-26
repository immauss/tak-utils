Script consolidation thoughts. 
The original scripts to start the DB are overly complex and redundant. They have never really been tuned for a container image and certainly not for Kubernetes. 
Here I'm keeping my notes on what needs to be done to clean this up. 
current execution path:
start-db.sh 
   - configure.sh 
      - takserver-setup-db.sh 
- start-db.sh 

The configure.sh ONLY sleeps for 3 seconds then calls the takserver-setup-db.sh 

takserver-setup & start-db both try to set the password for marti 
both also setup a pg_hb.conf 
several things need to be removed as they are not applicable to a k8s env.
passwords should be stored as secrets. This may be pointless as the DB password still needs to reside in the CoreConfig.xml for the java apps to access the DB. For mo betta security, java apss would need to pull from the secrets too. 
