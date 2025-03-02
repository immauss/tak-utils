#!/bin/bash

# Function to clean up and shut down PostgreSQL
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database stop" postgres
}
#this sets up a trap to call the cleanup function when the script exits
trap 'cleanup' EXIT

# Function to get the pod's subnet for updating pg_hba.conf
get_pod_net() {
    awk '$4 == "0001" 
        hex=$2; mask=$8;
        ip = sprintf("%d.%d.%d.%d", strtonum("0x" substr(hex,7,2)), strtonum("0x" substr(hex,5,2)), strtonum("0x" substr(hex,3,2)), strtonum("0x" substr(hex,1,2)));
        subnet = sprintf("%d.%d.%d.%d", strtonum("0x" substr(mask,7,2)), strtonum("0x" substr(mask,5,2)), strtonum("0x" substr(mask,3,2)), strtonum("0x" substr(mask,1,2)));
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

    # Extract password from CoreConfig.xml or CoreConfig.example.xml
    for config in /opt/tak/CoreConfig.xml; do
        if [ -f "$config" ]; then
            password=$(grep -m 1 "<connection" "$config" | sed 's/.*password="//; s/".*//')
            [ -n "$password" ] && break
        fi
    done

    # Use environment variable if set
    if [ -n "$envpass" ]; then
        password="$envpass"
        sed -i "s/password=\"\"/password=\"$envpass\"/g" /opt/tak/CoreConfig.example.xml
    fi

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
    fi
}

# Configure PostgreSQL access and restart
configure_postgresql() {
    local PGHBA=$(psql -AXqtc "SHOW hba_file")
    local POD_SUBNET=$(get_pod_net)

    echo "Updating pg_hba.conf with actual pod subnet $POD_SUBNET"
    sed -i "s|POD_SUBNET|$POD_SUBNET|" "$PGHBA"
    pg_ctl reload -D "$PGDATA"
}

# Start main process
setup_configs
/usr/local/bin/docker-entrypoint.sh postgres &
wait_for_postgres
setup_database
configure_postgresql



# Tail PostgreSQL log to keep container running
#tail -f /dev/null

# Wait for the main process to exit. This will happen when the container is stopped
# or the main process is killed, e.g. due to an error.
# the trap will then run the cleanup function to properly shut down PostgreSQL
wait $! 