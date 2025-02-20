
#!/bin/sh
# the CoreConfig.xml is mounted on volume. 
# This is the simplest way to maintain concurence across multiple containers.
# But since it we can't mount a file in kubernetes, we ln -s the file to file in the volume.
# This way we can update the file in the volume and the container will see the changes.
if [ -L /opt/tak/CoreConfig.xml ]; then
  echo "CoreConfig.xml is already a symlink"
else
  echo "CoreConfig.xml is not a symlink, linking..."
  if ! [ -f /opt/tak/config/CoreConfig.xml ]; then
    echo "CoreConfig.xml not found in /opt/tak/configs, creating..."
    mv /opt/tak/CoreConfig.xml /opt/tak/configs/CoreConfig.xml
  fi
  ln -sf  /opt/tak/configs/CoreConfig.xml /opt/tak/CoreConfig.xml
fi
# set and/or update the wait time.
# This give the database time to start up before we try to load the admin cert.
# This is a hacky way to do this, but it works.
if ! [ -f /tmp/wait ]; then
	echo "185" > /tmp/wait
else
	wait=$( expr $(cat /tmp/wait) + 10 )
	echo $wait > /tmp/wait
fi
# Define some functions
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

# Starting TAK server initialization
echo "Starting TAK server initialization..."

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

