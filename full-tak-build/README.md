# Using the TAK Server Hardened Iron Bank Docker Image
NOTE: Run these steps and setup the TAK Server container **after** running the steps to setup / run the TAK Server Database.  If you haven't already run them, start there first. 
First, run the steps located in the [IronBank Page for the TAK Server Database](https://ironbank.dso.mil/repomap/details;registry1Path=tpc%252Ftak%252Ftak-server-db)

## Pulling and running the TAK Server image from Iron Bank
Building the hardened takserver and tak-database docker images requires creating an [Iron Bank/Repo1](https://repo1.dso.mil/dsop/dccscr#overview) account to access approved base images.
To create an account, follow the steps in the [IronBank Getting Started](https://repo1.dso.mil/dsop/dccscr#getting-started) instructions.

### Perform a docker login into registry1
Assuming you've already setup a login as noted above:
```shell
docker login registry1.dso.mil
```

### Pull the image from registry1 to your local docker registry
Assuming you successfully logged into registry using a `docker login`:
```shell
docker pull registry1.dso.mil/ironbank/tpc/tak/tak-server:5.0
```
### You should have already setup the Docker Container network during setup of the TAK Server Database
Make sure you use the same network name from that setup when you execute the docker run command.  

### Run the TAK Server container and connecting it to the docker bridge network
Note that we use the network created in the TAK Server Database setup steps so that the TAK Server DB container will be visible to this container.
```shell
docker run -d -it -p 8080:8080 -p 8443:8443 -p 8444:8444 -p 8446:8446 -p 8087:8087/tcp -p 8087:8087/udp -p 8088:8088 -p 9000:9000 -p 9001:9001 --network takserver-net-hardened --name takserver-4.9 --env envpass=atakatak registry1.dso.mil/ironbank/tpc/tak/tak-server:5.0
```
### Set the password to connect to the database
```shell
docker exec -it takserver-5.0 bash -c "cd /opt/tak && vim ./CoreConfig.xml"
```
Once you have the file open, find the connection section and the text `password=''` and put in the same password you passed in via an `envpass` variable in the TAK Server Database setup.
Make sure the changes were saved.

### Restart the docker container
This will cause the TAK Server to use the newly specified password to connect with the database container. 

## Setting up the certificates for secure operation
After the TAK Server finishes startup, setup the certificates.  
### Edit the cert-metadata.sh file 
Set the `STATE`, `CITY` and `ORGANIZATIONAL_UNIT` variables in the file to values unique to your TAK Server setup.
```shell
docker exec -it takserver-5.0 bash -c "cd /opt/tak/certs && vim ./cert-metadata.sh"
```
### Generate the root certificate authority and certs
Replace `TAKServer` with whatever you want the root CA name to be or leave the default
```shell
docker exec -it takserver-5.0 bash -c "cd /opt/tak/certs && export CA_NAME='TAKServer' && generateClusterCertsIfNoneExist.sh"
```

### Load the client certificate into the User Manager for login
```shell
docker exec -it takserver-5.0 bash -c "cd /opt/tak && java -jar utils/UserManager.jar certmod -A certs/files/admin.pem"
```
### Restart the TAK Server container
This will cause the 'admin' cert to be loaded on startup and ready for use.

## Troubleshooting
- To view the takserver Messaging and API logs:
```shell
docker exec -it takserver-hardened bash -c "cd /opt/tak/logs/ && tail -f takserver-messaging.log"
docker exec -it takserver-hardened bash -c "cd /opt/tak/logs/ && tail -f takserver-api.log"
```
