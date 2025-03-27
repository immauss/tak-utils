## Environment variables outside image context. These will be available until the first FROM statement.
ARG BASE_REGISTRY=registry1.dso.mil
ARG BASE_IMAGE=ironbank/opensource/postgres/postgresql-15/postgis15
ARG BASE_TAG=15-3.5.2

####################################################################################################

## Base deploy image
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

ARG TAKSERVER_DEPENDENCY_FILENAME=takserver-docker-5.3-RELEASE-24
ARG TAKSERVER_DEPENDENCY_ZIPFILE=$TAKSERVER_DEPENDENCY_FILENAME.zip

USER root:root

# Upgrade first
#RUN dnf -y upgrade --nodocs \
#    && dnf clean all \
#    && rm -rf /var/cache/dnf

#RUN dnf -y install unzip java-17-openjdk libtiff libtiff-devel gmp-devel libX11-devel libwebp mesa-libGL poppler-utils libquadmath mesa-libGL libgbm libgfortran libglvnd-egl

 #COPY giflib-5.1.4-3.el8.x86_64.rpm CGAL.rpm OpenEXR-libs.rpm SFCGAL.rpm SFCGAL-libs.rpm SuperLU.rpm armadillo.rpm arpack.rpm atlas.rpm blas.rpm boost-atomic.rpm boost-chrono.rpm boost-date-time.rpm boost-serialization.rpm boost-system.rpm boost-thread.rpm cfitsio.rpm cmake-filesystem.rpm freexl.rpm gdal35-libs.rpm geos311.rpm glx-utils.rpm gpsbabel.rpm hdf.rpm hdf5.rpm ilmbase.rpm lapack.rpm libICE.rpm libSM.rpm libaec.rpm libbsd.rpm libevdev.rpm libgeotiff16.rpm libgeotiff16-devel.rpm libgomp.rpm libgta.rpm libgudev.rpm libinput.rpm libkml.rpm libmd.rpm libqhull_r.rpm  librttopo.rpm libspatialite50.rpm libspatialite50-devel.rpm libtool-ltdl.rpm libusb.rpm libwacom.rpm libwacom-data.rpm libxkbcommon-x11.rpm mariadb-connector-c.rpm mariadb-connector-c-config.rpm minizip.rpm mtdev.rpm netcdf.rpm ogdi41.rpm openblas.rpm openblas-openmp.rpm openblas-threads.rpm openblas-threads64_.rpm pcre2-utf16.rpm proj82.rpm proj90.rpm protobuf-c.rpm qt5-qtbase.rpm qt5-qtbase-common.rpm qt5-qtbase-gui.rpm qt5-qtsvg.rpm shapelib.rpm unixODBC.rpm uriparser.rpm xcb-util.rpm xcb-util-image.rpm xcb-util-keysyms.rpm xcb-util-renderutil.rpm xcb-util-wm.rpm xerces-c.rpm ./

 #RUN rpm -Uvh giflib-5.1.4-3.el8.x86_64.rpm CGAL.rpm OpenEXR-libs.rpm SFCGAL.rpm SFCGAL-libs.rpm SuperLU.rpm armadillo.rpm arpack.rpm atlas.rpm blas.rpm boost-atomic.rpm boost-chrono.rpm boost-date-time.rpm boost-serialization.rpm boost-system.rpm boost-thread.rpm cfitsio.rpm cmake-filesystem.rpm freexl.rpm gdal35-libs.rpm geos311.rpm glx-utils.rpm gpsbabel.rpm hdf.rpm hdf5.rpm ilmbase.rpm lapack.rpm libICE.rpm libSM.rpm libaec.rpm libbsd.rpm libevdev.rpm libgeotiff16.rpm libgeotiff16-devel.rpm libgomp.rpm libgta.rpm libgudev.rpm libinput.rpm libkml.rpm libmd.rpm libqhull_r.rpm  librttopo.rpm libspatialite50.rpm libspatialite50-devel.rpm libtool-ltdl.rpm libusb.rpm libwacom.rpm libwacom-data.rpm libxkbcommon-x11.rpm mariadb-connector-c.rpm mariadb-connector-c-config.rpm minizip.rpm mtdev.rpm netcdf.rpm ogdi41.rpm openblas.rpm openblas-openmp.rpm openblas-threads.rpm openblas-threads64_.rpm pcre2-utf16.rpm proj82.rpm proj90.rpm protobuf-c.rpm qt5-qtbase.rpm qt5-qtbase-common.rpm qt5-qtbase-gui.rpm qt5-qtsvg.rpm shapelib.rpm unixODBC.rpm uriparser.rpm xcb-util.rpm xcb-util-image.rpm xcb-util-keysyms.rpm xcb-util-renderutil.rpm xcb-util-wm.rpm xerces-c.rpm


# Should point this to a repo and then install from the repo instead of pulling the rpm everytime.
#  Install EPEL repo RPM:
#COPY epel-release-latest-8.noarch.rpm .
#RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
#    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
#RUN dnf -y install epel-release-latest-8.noarch.rpm


#COPY postgres.repo /etc/yum.repos.d/postgres.repo
#RUN dnf install -y --enablerepo=PowerTools qhull-devel
#RUN dnf install -y --enablerepo=RL8-AppStream \ 
#    boost-system boost-thread boost-serialization boost-date-time boost-chrono boost-atomic
#RUN dnf install -y gdal35-devel
#RUN dnf install postgis34_16 -y --nodocs  --nobest \
#    && dnf clean all \
#    && rm -rf /var/cache/dnf


# you might need to do this instead for the Rockys
#dnf config-manager --enable crb

# for Rocky 8 and above might need to do this as well
#crb enable

# Now, you can finally install PostGIS
# Select the right PostGIS and PostgreSQL versions
#dnf -y install postgis34_16



#RUN sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/pgsql-15/share/postgresql.conf.sample \
#    && dnf clean all \
#    && rm -rf /var/cache/dnf

RUN usermod -a -G root postgres

VOLUME /var/lib/postgresql/data

RUN chown -R postgres:postgres /var/lib/postgresql && \
    chmod -R 775 /var/lib/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod -R 777 /var/run/postgresql && \
    chown -R postgres:postgres /var/lib/pgsql && \
    chmod -R 770 /var/lib/pgsql

ENV POSTGRES_HOST_AUTH_METHOD=trust

#runs in takserver-setup-db.sh but fails because of permissions. running as root to prevent error


RUN usermod -a -G root postgres

COPY --chown=postgres:0 $TAKSERVER_DEPENDENCY_ZIPFILE /opt/tak/
RUN cd /opt/tak && unzip $TAKSERVER_DEPENDENCY_ZIPFILE
RUN cd /opt/tak && rm $TAKSERVER_DEPENDENCY_ZIPFILE

RUN mkdir /opt/tak/db-utils/
RUN cp -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME/db-utils/* /opt/tak/db-utils/
RUN cp -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME/CoreConfig.example.xml /opt/tak/CoreConfig.example.xml 
COPY --chown=postgres:0 scripts/configureInDocker.sh /opt/tak/db-utils/configureInDocker.sh
RUN rm -r /opt/tak/$TAKSERVER_DEPENDENCY_FILENAME

RUN chmod u=rwx /opt/tak \
    && find /opt/tak/ -type d -exec chmod u=rwx {} \; \
	&& find /opt/tak/ -type f -name "*.*" -exec chmod u=rw {} \; \
	&& find /opt/tak/ -type f -name "*.sh" -exec chmod u=rx {} \;

USER postgres:0

HEALTHCHECK --start-period=120s --interval=30s --timeout=30s --retries=10 CMD opt/tak/health/takserver-db/health_check.sh || exit 1


# Default startup executable. Can include elements of 'docker run' command as parameters.
ENTRYPOINT ["/opt/tak/db-utils/configureInDocker.sh"]