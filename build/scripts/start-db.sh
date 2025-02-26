#!/bin/bash
# Ugly function to get the pod's subnet
# This is needed to update the pg_hba.conf file with the actual subnet of the pod.
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

# echo "Installing TAKServer's version of PostgreSQL access-control policy."
# PGHBA=$(psql -AXqtc "SHOW hba_file")
# cp /opt/tak/db-utils/pg_hba.conf $PGHBA
# chmod 600 $PGHBA
# #replace subnet in pghba with actual subnet of the pod
# POD_SUBNET=$(get_pod_net)
# echo "Fixing pg_hba.conf with actual pod subnet $POD_SUBNET"
# echo "Pod Subnet: $POD_SUBNET"
# sed -i "s|POD_SUBNET|$POD_SUBNET|" $PGHBA
# pg_ctl reload -D $PGDATA

cd /opt/tak/db-utils
./takserver-setup-db.sh
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

