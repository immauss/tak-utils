#!/bin/bash

# Function to cleanly shut down PostgreSQL
cleanup() {
    echo "Container stopped, performing shutdown"
    /usr/pgsql-15/bin/pg_ctl -m fast -D $PGDATA
}
#this sets up a trap to call the cleanup function when the script exits
trap 'cleanup' EXIT

# Function to get the pod's subnet for updating pg_hba.conf
get_pod_net() {
    awk '
    $4 == "0001" {
        hex=$2; mask=$8;
        
        # Convert hex to IP
        ip = sprintf("%d.%d.%d.%d", 
            strtonum("0x" substr(hex,7,2)), 
            strtonum("0x" substr(hex,5,2)), 
            strtonum("0x" substr(hex,3,2)), 
            strtonum("0x" substr(hex,1,2)));

        # Convert mask to subnet
        subnet = sprintf("%d.%d.%d.%d", 
            strtonum("0x" substr(mask,7,2)), 
            strtonum("0x" substr(mask,5,2)), 
            strtonum("0x" substr(mask,3,2)), 
            strtonum("0x" substr(mask,1,2)));

        # Convert subnet mask to CIDR notation
        cidr = 0;
        split(subnet, octets, ".");
        for (i=1; i<=4; i++) {
            num = octets[i] + 0;
            while (num > 0) {
                cidr += and(num, 1);
                num = rshift(num, 1);
            }
        }

        print ip "/" cidr;
    }' /proc/net/route
}


# Ensure necessary config files are properly linked
setup_configs() {
    if [ ! -L /opt/tak/CoreConfig.xml ]; then
        echo "Setting up configs..."
        rm -f /opt/tak/*.xml
        for file in /opt/tak/configs/*.xml; do
            ln -sf "$file" "/opt/tak/$(basename "$file")"
        done
    fi
}

# Wait for PostgreSQL to start
wait_for_postgres() {
    echo "Waiting for PostgreSQL server to start..."
    while ! pg_isready -d postgres -h localhost -U postgres; do
        echo "PostgreSQL server is not ready"
        sleep 2
    done
    echo "PostgreSQL server is ready"
}

# Function to set up the database
setup_database() {
    local username='martiuser'
    local password=""

    # Extract password from CoreConfig.xml 
    for config in /opt/tak/CoreConfig.xml; do
        if [ -f "$config" ]; then
            password=$(grep -m 1 "<connection" "$config" | sed 's/.*password="//; s/".*//')
            [ -n "$password" ] && break
        fi
    done


    # Ensure password is set
    if [ -z "$password" ]; then
        echo "ERROR: No database password found! Provide one as an argument."
        exit 1
    fi

    # Set up PostgreSQL user and database
    local md5pass=$(echo -n "md5" && echo -n "$password$username" | md5sum | tr -dc "a-zA-Z0-9")
    local db_name=${1:-cot}

    if ! psql -U postgres -AXqtc "SELECT 1 FROM pg_roles WHERE rolname='$username'" | grep -q 1; then
        echo "Creating user $username..."
        psql -U postgres -c "CREATE ROLE $username LOGIN PASSWORD '$password' SUPERUSER INHERIT CREATEDB NOCREATEROLE;"
    fi

    if ! psql -XtAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
        echo "Creating database $db_name..."
        createdb -U postgres --owner=$username $db_name
        # Setup the database schema
        java -jar /opt/tak/db-utils/SchemaManager.jar upgrade
        if [ $? -ne 0 ]; then
            echo "ERROR: Unable to update database schema!"
            exit 1
        else
            echo "Database updated with SchemaManager.jar"
        fi
    fi
}
configure_postgres() {
    echo "Create Archive directory"
    mkdir -p /var/lib/postgresql/archivedir
    echo "Applying tak postgresql.conf "
    mkdir -p /var/lib/postgresql/data
    cp /opt/tak/db-utils/*.conf /var/lib/postgresql/data/
    local POD_SUBNET=$(get_pod_net)

    echo "Updating pg_hba.conf with actual pod subnet $POD_SUBNET"
    sed -i "s|POD_SUBNET|$POD_SUBNET|" /var/lib/postgresql/data/pg_hba.conf

    echo "Restarting PostgreSQL service."
    pg_ctl stop -m fast -D "$PGDATA"
    pg_ctl start -D "$PGDATA"
    touch $PGDATA/initialized

}



# Start main process
setup_configs
# run the Generic PostgreSQL entrypoint script to get it setup and started
/usr/local/bin/docker-entrypoint.sh postgres &
# wait for postgres to start
wait_for_postgres
# config posgresql and setup the database
if [ ! -f $PGDATA/initialized ]; then
    configure_postgres
    setup_database
fi
# Wait for the main process to exit. This will happen when the container is stopped
# or the main process is killed, e.g. due to an error.
# the trap will then run the cleanup function to properly shut down PostgreSQL
# this will hopefull prevent the database from getting corrupted
wait $! 