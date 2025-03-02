#!/bin/bash
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database stop" postgres
}
# Ugly function to get the pod's subnet
# This is needed to update the pg_hba.conf file with the actual subnet of the pod.
# The problem here is that the normal tools to get the subnet are not available in the container.
# So we have to do some awk magic to get the subnet.
# This is a bit of a hack, but it works.
function get_pod_net() {
	awk '$4 == "0001" {
    hex=$2; mask=$8;
    ip = sprintf("%d.%d.%d.%d", strtonum("0x" substr(hex,7,2)), strtonum("0x" substr(hex,5,2)), strtonum("0x" substr(hex,3,2)), strtonum("0x" substr(hex,1,2)));
    subnet = sprintf("%d.%d.%d.%d", strtonum("0x" substr(mask,7,2)), strtonum("0x" substr(mask,5,2)), strtonum("0x" substr(mask,3,2)), strtonum("0x" substr(mask,1,2)));
    cidr = 0;
    split(subnet, octets, ".");
    for (i=1; i<=4; i++) {
        num = octets[i] + 0;  # Convert string to number
        while (num > 0) {
            cidr += and(num, 1);  # Count 1s in binary representation
            num = rshift(num, 1); # Right shift to check next bit
        }
    }
    print ip "/" cidr;
}' /proc/net/route

}
# the configs are in external storage for persistence.
# We assume the user as populated the volume or storage with all of the configs.
# Otherewise ... it won't work .... So they shoudl be there, we just need to link them.
# Check to see if the CoreConfig.xml is a symlink, if not, link all the XMLs in /opt/tak/configs to /opt/tak
if [ -L /opt/tak/CoreConfig.xml ]; then
  echo "/opt/tak/CoreConfig.xml is already a symlink"
else
  echo "/opt/tak/CoreConfig.xml is not a symlink, setting up configs..."
  # Check to see if there are any xml files in /opt/tak/configs
  # if not, move them there.
  rm /opt/tak/*.xml
  for file in /opt/tak/configs/*.xml; do
    ln -sf $file /opt/tak/$(basename $file)
  done
fi
# This script will wait until the final postgres (which allows connections) started in the /docker-entrypoint.sh.
# Then, create and initialize all the databases.
echo "Running docker-entrypoint.sh"
/usr/local/bin/docker-entrypoint.sh postgres &

echo "Waiting for postgres server to start"
while true; do
	sleep 2
		pg_isready -d postgres -h localhost -U postgres
		success=$?
		if [ $success -ne 0 ]; then
			 echo "postgres server is not ready"
		else
			echo "postgres server is ready"
			break
		fi
done



cd /opt/tak/db-utils
##############################
# Begining of takserver-setup-db.sh script pasted into this one
##############################
echo "TAK Server DB Setup [Docker Hardened]"

username='martiuser'
password=""
# try to get password from /opt/tak/CoreConfig.xml
if [ -f "/opt/tak/CoreConfig.xml" ]; then
  password=$(echo $(grep -m 1 "<connection" /opt/tak/CoreConfig.xml)  | sed 's/.*password="//; s/".*//')
fi
# try to get password from /opt/tak/CoreConfig.example.xml
if [ -z "$password" ]; then
  if [ -f "/opt/tak/CoreConfig.example.xml" ]; then
    password=$(echo $(grep -m 1 "<connection" /opt/tak/CoreConfig.example.xml)  | sed 's/.*password="//; s/".*//')
  fi
fi

# If the envpass environment variable is set, set the password for the example. 
# This allows for prebuilt docker containers (such as ironbank) to have configuration passed to them
if [ ! -z "$envpass" ]; then
  password=$envpass
  sed -i "s/password=\"\"/password=\"$envpass\"/g" /opt/tak/CoreConfig.example.xml
fi

# cant find password - request one from user
if [ -z "$password" ]; then
  : ${1?' Could not find a password in /opt/tak/CoreConfig.xml or /opt/tak/CoreConfig.example.xml. Please supply a plaintext database password as the first parameter'}
  password=$1
fi

md5pass=$(echo -n "md5" && echo -n "$password$username" | md5sum | tr -dc "a-zA-Z0-9\n")

# switch CWD to the location where this script resides
cd `dirname $0`
DB_NAME=$1
if [ $# -lt 1 ]; then
  DB_NAME=cot
fi

DB_INIT=""
# Ensure PostgreSQL is initialized.

if [ -x /usr/pgsql-15/bin/postgresql-15-setup ]; then
    DB_INIT="/usr/pgsql-15/bin/postgresql-15-setup initdb"
else
    echo "WARNING: Unable to automatically initialize PostgreSQL database."
fi

echo -n "Database initialization: " 
$DB_INIT 
if [ $? -eq 0 ]; then
    echo "PostgreSQL database initialized."
else
    echo "WARNING: Failed to initialize PostgreSQL database."
    echo "This could simply mean your database has already been initialized."
fi
      
# Figure out where the system keeps the PostgreSQL data

if [ -z ${PGDATA+x} ]; then
   if [ -d /var/lib/pgsql/15/data ]; then
        export PGDATA=/var/lib/pgsql/15/data
        POSTGRES_CMD="service postgresql-15 restart"
   else
       echo "PGDATA not set and unable to find PostgreSQL data directory automatically."
       echo "Please set PGDATA and re-run this script."
       exit 1
   fi
fi

if [ ! -d $PGDATA ]; then
  echo "ERROR: Cannot find PostgreSQL data directory. Please set PGDATA manually and re-run."
  exit 1
fi

# Get user's permission before obliterating the database
DB_EXISTS=`psql -l 2>/dev/null | grep ^[[:blank:]]*$DB_NAME`
if [ "x$DB_EXISTS" != "x" ]; then
   echo "WARNING: Database '$DB_NAME' already exists!"
   echo "Proceeding will DESTROY your existing data!"
   echo "You can back up your data using the pg_dump command. (See 'man pg_dump' for details.)"
   read -p "Type 'erase' (without quotes) to erase the '$DB_NAME' database now:" kickme
   if [ "$kickme" != "erase" ]; then
       echo "User didn't say 'erase'. Aborting."
       exit 1
   fi
   #su postgres -c "psql --command='drop database if exists $DB_NAME;'"
   psql --command='drop database if exists $DB_NAME;'
fi

IS_DOCKER=false
if [ -e pg_hba.conf ]; then
  IS_DOCKER=true
fi

# Verify and add en_US.UTF-8 locale on Debian based installations
if ! $(locale -a | grep -iq en_US.UTF8); then 
  if [ -e /etc/locale.gen ]; then
    echo "Adding en_US.UTF-8 locale"
    sudo sed -i -e"s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
    sudo locale-gen
  fi
fi

# Start PG services to allow identification of data directory and config files
echo "(Re)starting PostgreSQL service."
$POSTGRES_CMD

# Install our version of pg_hba.conf
echo "Installing TAKServer's version of PostgreSQL access-control policy."
PGHBA=$(psql -AXqtc "SHOW hba_file")
# Back up pg_hba.conf
BACKUP_SUFFIX=`date --rfc-3339='seconds' | sed 's/ /-/'`
HBA_BACKUP=$PGHBA.backup-$BACKUP_SUFFIX
if [ -e /opt/tak/db-utils/pg_hba.conf ] || [ -e pg_hba.conf ]; then
  if [ -e $PGHBA ]; then
    mv $PGHBA $HBA_BACKUP
    echo "Copied existing PostgreSQL access-control policy to $HBA_BACKUP."
  fi

   # for docker install
  if [ "$IS_DOCKER" = true ]; then
    echo "Docker db install"
    cp pg_hba.conf $PGHBA
  else
    # for RPM install
    echo "RPM/DEB db install"
    cp /opt/tak/db-utils/pg_hba.conf $PGHBA
  fi

  echo "Installed TAKServer's PostgreSQL access-control policy to $PGHBA."
  echo "Restarting PostgreSQL service."
  $POSTGRES_CMD
else
  echo "ERROR: Unable to find pg_hba.conf!"
  exit 1
fi

PGCONFIG=$(psql -AXqtc "SHOW config_file")
CONF_BACKUP=$PGCONFIG.backup-$BACKUP_SUFFIX
if [ -e /opt/tak/db-utils/postgresql.conf ] || [ -e postgresql.conf ];  then
  PGIDENT=$(psql -AXqtc "SHOW ident_file")

  if [ -e $PGCONFIG ]; then
    mv $PGCONFIG $CONF_BACKUP
    echo "Copied existing PostgreSQL configuration to $CONF_BACKUP."
  fi

   # for docker install
  if [ "$IS_DOCKER" = true ]; then
    cp postgresql.conf $PGCONFIG
  else
    # for RPM install
    echo "RPM/DEB db install"
    cp /opt/tak/db-utils/postgresql.conf $PGCONFIG
  fi

  # multi distro compatibility
  sed -i -e"s|^[# ]*data_directory[ ]*=.*$|data_directory = '$PGDATA'|" $PGCONFIG
  sed -i -e"s|^[# ]*hba_file[ ]*=.*$|hba_file = '$PGHBA'|" $PGCONFIG
  sed -i -e"s|^[# ]*ident_file[ ]*=.*$|ident_file = '$PGIDENT'|" $PGCONFIG

  echo "Installed TAKServer's PostgreSQL configuration to $PGCONFIG."
  echo "Restarting PostgreSQL service."
  $POSTGRES_CMD
fi

# Use pg_ctl command to restart PG service in Docker and take up new hba/config
pg_ctl restart

DB_NAME=cot
if [ $# -eq 1 ] ; then
    DB_NAME=$1
fi

# Create the user "martiuser" if it does not exist.
martiuser_exists=`psql -U postgres -AXqtc "SELECT 1 FROM pg_roles WHERE rolname='$username'"`
if [ $? -eq 0 ] && [ "$martiuser_exists" = "1" ]; then
    echo "Postgres user \"$username\" exists."
else
    echo "Creating user \"$username\" ..."
    psql -U postgres -c "CREATE ROLE $username LOGIN PASSWORD '$password' SUPERUSER INHERIT CREATEDB NOCREATEROLE;"
    if [ $? -ne 0 ]; then
        echo "Something went wrong with creating user '$username'.  Exiting..."
        exit 1
    fi
fi

# create the database if it doesn't exist
db_exists=`psql -XtAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'"`
if [ $? -eq 0 ] && [ "$db_exists" = "1" ]; then
  echo "Database already created..."
else
    # create the database
    echo "Creating database $DB_NAME"
    createdb -U postgres --owner=$username $DB_NAME
    if [ $? -ne 0 ]; then
        echo "Something went wrong with creating the database $DB_NAME.  Exiting..."
        exit 1
    fi
    echo "Database $DB_NAME created."
fi

if [ "$IS_DOCKER" = true ]; then
   java -jar SchemaManager.jar upgrade
elif [ -e /opt/tak/db-utils/SchemaManager.jar ]; then
   java -jar /opt/tak/db-utils/SchemaManager.jar upgrade
else
   echo "ERROR: Unable to find SchemaManager.jar!"
   exit 1
fi

echo "Database updated with SchemaManager.jar"

if [ ! -x /usr/bin/systemctl ]; then
  echo "Systemctl was not found. Skipping Systemd configuration."
  exit 1
fi

# Set PostgreSQL to run automatically at boot time
if [ -d /var/lib/pgsql/15/data ]; then
    START_INIT="chkconfig --level 345 postgresql-15 on"
else
  echo "ERROR: unable to detect postgres version to start on boot"
  exit 1
fi
    
$START_INIT
echo "set postgres to start on boot"


##############################
# End of takserver-setup-db.sh script pasted into this one
##############################
echo "Setting martiuser password"
PASSWORD=$(echo $(grep -m 1 "<connection" /opt/tak/CoreConfig.xml)  | sed 's/.*password="//; s/".*//')
psql -U postgres -c "ALTER ROLE martiuser PASSWORD '$PASSWORD' ;"
#replace subnet in pghba with actual subnet of the pod
PGHBA=$(psql -AXqtc "SHOW hba_file")
POD_SUBNET=$(get_pod_net)
echo "Fixing pg_hba.conf with actual pod subnet $POD_SUBNET"
echo "Pod Subnet: $POD_SUBNET"
sed -i "s|POD_SUBNET|$POD_SUBNET|" $PGHBA
pg_ctl reload -D $PGDATA
java -jar SchemaManager.jar upgrade

# This should tail the postgres log
tail -f /dev/null

