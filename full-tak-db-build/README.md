# Using the TAK Server DB Hardened Iron Bank Docker Image
NOTE: Run these steps and setup the TAK Server DB container **before** running the steps to setup / run the TAK Server itself.

## Pulling and running the TAK Server DB image from Iron Bank
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
docker pull registry1.dso.mil/ironbank/tpc/tak/tak-server-db:5.0
```

### Create the docker 'bridge network' to run takserver and its database inside of
You'll want to setup this network to make the docker containers on the network aware of all the other containers on the network.
```
docker network create takserver-net-hardened 
```

### Run the TAK Server DB container and connecting it to the docker bridge network
Note that `5432` is the default Postgresql port.   Also note that we use the network created above and give this container an 
alias within the network of `tak-database` which is the default hostname for the database in our TAK Server postgresql connection URL.
```shell
docker run -d -it -p 5432:5432 --network takserver-net-hardened --network-alias tak-database --name takserver-db-5.0 --env envpass=atakatak registry1.dso.mil/ironbank/tpc/tak/tak-server-db:5.0
```

## Troubleshooting
- To view the `takserver-db` container postgresql startup log:
```shell
docker exec -it takserver-db bash -c "cd /var/lib/postgresql && tail -f logfile"
```

## Next steps
Run the steps in the Readme at the bottom of the [TAK Server 5.0 Hardened container page](https://ironbank.dso.mil/repomap/details;registry1Path=tpc%252Ftak%252Ftak-server).
This will setup and run Hardened TAK Server container to connect to and use this TAK Server DB container.


