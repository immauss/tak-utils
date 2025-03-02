
#!/bin/sh

# set and/or update the wait time.
# This give the database time to start up before we try to load the admin cert.
# This is a hacky way to do this, but it works.
if ! [ -f /tmp/wait ]; then
	echo "185" > /tmp/wait
else
	wait=$( expr $(cat /tmp/wait) + 10 )
	echo $wait > /tmp/wait
fi
###################################
####### Define some functions #####
###################################
# the configs are in external storage for persistence.
# We assume the user has populated the volume or storage with all of the configs.
# Otherewise ... it won't work .... So they shoudl be there, we just need to link them.
# Check to see if the CoreConfig.xml is a symlink, if not, link all the XMLs in /opt/tak/configs to /opt/tak
setup_configs() {
    if [ ! -L /opt/tak/CoreConfig.xml ]; then
        echo "Setting up configs..."
        rm -f /opt/tak/*.xml
        for file in /opt/tak/configs/*.xml; do
            ln -sf "$file" "/opt/tak/$(basename "$file")"
        done
    fi
}
# This function will load the admin cert into the TAK server.
# This is a one time operation 

LoadAdmin() {
  if [ -f /opt/tak/CoreConfig.xml ]; then
	  echo "/opt/tak/CoreConfig.xml found"
  else
	  echo -e "No config found at /opt/tak/CoreConfig.xml\nCheck your docker-compose.yaml and ensure the file exists in the current directory"
	  exit
  fi
  echo "Loading Admin cert"
  cd /opt/tak && java -jar utils/UserManager.jar certmod -A certs/files/admin.pem 
  ERROR="$?"
  if [ $ERROR -ne 0 ]; then
    echo -e "Looks like cert loading failed\n$ERROR"
    echo "Exiting to force container restart"
    exit
  else 
    echo " Admin cert loaded successfully"
    # We'll look for this on startup and skip the AdminLoad if it exists.
    echo "Marking admin as loaded"
    touch /opt/tak/configs/admin.loaded
    echo " Exiting to force container resart on new cert "
    exit
  fi

}
wait_for_postgres() {
    echo "Waiting for PostgreSQL server to start..."
    while ! /usr/pgsql-15/bin/pg_isready -h takserver-db; do
        echo "PostgreSQL server is not ready"
        sleep 2
    done
    echo "PostgreSQL server is ready"
}



# Starting TAK server initialization
echo "Starting TAK server initialization..."
setup_configs

# Check if certs already exist before generating
if [ ! -f /opt/tak/certs/files/ca.pem ]; then
  echo "Certificates not found. Generating new certificates..."
  cd /opt/tak/certs && export CA_NAME="$PUBLIC_FQDN" && ./generateClusterCerts.sh
  echo "Certificates generated successfully."
else
  echo "Certificates already exist. Skipping generation."
fi


# Run TAK server setup script
echo "Running TAK server setup script..."
# make sure the DB is running before we start the TAK server
wait_for_postgres
# Run the TAK server setup/start script
/opt/tak/configureInDocker.sh init &>> /opt/tak/logs/takserver.log &

# Only load the admin cert if needed.
# This should be stored on  a persistent location so we don't do this on a 
# container rebuild with existing data.
if ! [ -f /opt/tak/configs/admin.loaded ]; then
	echo "Waiting for $(cat /tmp/wait) seconds"
	date
	sleep $(cat /tmp/wait)
	LoadAdmin 
fi

# Keep the container alive by tailing the log files
echo "Starting log tailing..."
tail -F /opt/tak/logs/*.log

