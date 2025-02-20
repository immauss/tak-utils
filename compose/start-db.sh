#!/bin/bash
# the CoreConfig.xml is mounted on volume. 
# This is the implest way to maintain concurence across multiple containers.
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
# This script will wait until the final postgres (which allows connections) started in the /docker-entrypoint.sh.
# Then, create and initialize all the databases.
/usr/local/bin/docker-entrypoint.sh postgres &

while true; do
	sleep 2
		pg_isready -d postgres -h localhost -U postgres
		success=$?
		if [ $success -ne 0 ]; then
		 echo "postgres server is not ready"
		 continue;
		fi
		echo "postgres server is ready"

		echo "Installing TAKServer's version of PostgreSQL access-control policy."
		PGHBA=$(psql -AXqtc "SHOW hba_file")
		cp /opt/tak/db-utils/pg_hba.conf $PGHBA
		chmod 600 $PGHBA
		pg_ctl reload -D $PGDATA

		cd /opt/tak/db-utils
		./configure.sh
		echo "Setting martiuser password"
		PASSWORD=$(echo $(grep -m 1 "<connection" /opt/tak/CoreConfig.xml)  | sed 's/.*password="//; s/".*//')
		psql -U postgres -c "ALTER ROLE martiuser PASSWORD '$PASSWORD' ;"

		java -jar SchemaManager.jar upgrade
		tail -f /dev/null

		break
done
