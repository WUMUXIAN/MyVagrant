
#!/bin/bash
#title           :wildfly-install.sh
#description     :The script to install Wildfly 9.0.2
#author	         :Dmitriy Sukharev
#contributor     :Kenner Kliemann
#date            :14-11-2015
#usage           :/bin/bash wildfly-install.sh
#tested-version  :9.0.0-Final
#tested-distros  :CentOS 7; Ubuntu 14.04

WILDFLY_VERSION='9.0.0.Final'
WILDFLY_FILENAME="wildfly-$WILDFLY_VERSION"
WILDFLY_ARCHIVE_NAME="$WILDFLY_FILENAME.tar.gz"
WILDFLY_DOWNLOAD_ADDRESS="http://download.jboss.org/wildfly/$WILDFLY_VERSION/$WILDFLY_ARCHIVE_NAME"
JDBC_ARCHIVE_NAME='postgresql-9.4-1206-jdbc42.jar'
JDBC_DOWLOAD_ADDRESS="https://jdbc.postgresql.org/download/$JDBC_ARCHIVE_NAME"

INSTALL_DIR=/opt
WILDFLY_FULL_DIR=$INSTALL_DIR/$WILDFLY_FILENAME
WILDFLY_DIR=$INSTALL_DIR/wildfly

WILDFLY_USER="wildfly"
WILDFLY_SERVICE="wildfly"
WILDFLY_MODE="standalone"

WILDFLY_STARTUP_TIMEOUT=240
WILDFLY_SHUTDOWN_TIMEOUT=30


if [[ $EUID -ne 0 ]]; then
echo "This script must be run as root."
exit 1
fi

# Install Java
echo "Install Java"
sudo yum install wget -y
wget --no-cookies --no-check-certificate "http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jdk-8u60-linux-x64.rpm" --header "Cookie:gpw_e24=http%3A%2F%2Fwww.oracle.com%2F;oraclelicense=accept-securebackup-cookie"
sudo yum installlocal jdk-8u60-linux-x64.rpm -y
sudo rm jdk-8u60-linux-x64.rpm
export JAVA_HOME=/usr/java/jdk1.8.0_60/

# Downlaoad wildfly
echo "Downloading: $WILDFLY_DOWNLOAD_ADDRESS..."
[ -e "$WILDFLY_ARCHIVE_NAME" ] && echo 'Wildfly archive already exists.'
if [ ! -e "$WILDFLY_ARCHIVE_NAME" ]; then
wget -q $WILDFLY_DOWNLOAD_ADDRESS
if [ $? -ne 0 ]; then
echo "Not possible to download Wildfly."
exit 1
fi
fi

# Download pg jdbc
echo "Downloading: $JDBC_DOWLOAD_ADDRESS..."
[ -e "$JDBC_ARCHIVE_NAME" ] && echo 'Postgres JDBC archive already exists.'
if [ ! -e "$JDBC_ARCHIVE_NAME" ]; then
wget -q $JDBC_DOWLOAD_ADDRESS
if [ $? -ne 0 ]; then
echo "Not possible to download postgresql JDBC."
exit 1
fi
fi

echo "Cleaning up..."
rm -rf "$WILDFLY_DIR"
rm -rf "$WILDFLY_FULL_DIR"
rm -rf "/var/run/$WILDFLY_SERVICE/"
rm -f "/etc/init.d/$WILDFLY_SERVICE"

echo "Installation..."
mkdir $WILDFLY_FULL_DIR
tar -xzf $WILDFLY_ARCHIVE_NAME -C $INSTALL_DIR
mv $WILDFLY_FULL_DIR $WILDFLY_DIR

useradd -s /sbin/nologin $WILDFLY_USER
chown -R $WILDFLY_USER:$WILDFLY_USER $WILDFLY_DIR
chown -R $WILDFLY_USER:$WILDFLY_USER $WILDFLY_DIR/
chown -R $WILDFLY_USER:$WILDFLY_USER $WILDFLY_DIR/standalone/

echo "Registrating Wildfly as service with launch and systemctl..."
# if should use systemd
if [ -x /bin/systemctl ]; then

cat > $WILDFLY_DIR/bin/launch.sh << "EOF"
#!/bin/sh
if [ "x$WILDFLY_HOME" = "x" ]; then
WILDFLY_HOME="/opt/wildfly"
fi
if [ "x$1" = "xdomain" ]; then
echo 'Starting Wildfly in domain mode.'
$WILDFLY_HOME/bin/domain.sh -c $2 -b $3
#>> /var/log/$WILDFLY_SERVICE/server-`date +%Y-%m-%d`.log
else
echo 'Starting Wildfly in standalone mode.'
$WILDFLY_HOME/bin/standalone.sh -c $2 -b $3
#>> /var/log/$WILDFLY_SERVICE/server-`date +%Y-%m-%d`.log
fi
EOF

# $WILDFLY_HOME is not visible here
sed -i -e 's,WILDFLY_HOME=.*,WILDFLY_HOME='$WILDFLY_DIR',g' $WILDFLY_DIR/bin/launch.sh
chmod +x $WILDFLY_DIR/bin/launch.sh

cp $WILDFLY_DIR/bin/init.d/wildfly-init-redhat.sh /etc/init.d/$WILDFLY_SERVICE
WILDFLY_SERVICE_CONF=/etc/default/wildfly.conf
chmod 755 /etc/init.d/$WILDFLY_SERVICE

systemctl daemon-reload
systemctl enable $WILDFLY_SERVICE.service
fi

# if non-systemd Debian-like distribution
if [ ! -x /bin/systemctl -a -r /lib/lsb/init-functions ]; then
cp $WILDFLY_DIR/bin/init.d/wildfly-init-debian.sh /etc/init.d/$WILDFLY_SERVICE
chmod 755 /etc/init.d/$WILDFLY_SERVICE
WILDFLY_SERVICE_CONF=/etc/default/$WILDFLY_SERVICE
fi

if [ ! -z "$WILDFLY_SERVICE_CONF" ]; then
echo "Configuring service..."
echo JBOSS_HOME=\"$WILDFLY_DIR\" > $WILDFLY_SERVICE_CONF
echo JBOSS_USER=$WILDFLY_USER >> $WILDFLY_SERVICE_CONF
echo STARTUP_WAIT=$WILDFLY_STARTUP_TIMEOUT >> $WILDFLY_SERVICE_CONF
echo SHUTDOWN_WAIT=$WILDFLY_SHUTDOWN_TIMEOUT >> $WILDFLY_SERVICE_CONF
echo WILDFLY_CONFIG=$WILDFLY_MODE.xml >> $WILDFLY_SERVICE_CONF
echo WILDFLY_MODE=$WILDFLY_MODE >> $WILDFLY_SERVICE_CONF
echo WILDFLY_BIND=0.0.0.0 >> $WILDFLY_SERVICE_CONF
fi

echo "Configuring application server..."
sed -i -e 's,<deployment-scanner path="deployments" relative-to="jboss.server.base.dir" scan-interval="5000",<deployment-scanner path="deployments" relative-to="jboss.server.base.dir" scan-interval="5000" deployment-timeout="'$WILDFLY_STARTUP_TIMEOUT'",g' $WILDFLY_DIR/$WILDFLY_MODE/configuration/$WILDFLY_MODE.xml
sed -i -e 's,<inet-address value="${jboss.bind.address:127.0.0.1}"/>,<any-address/>,g' $WILDFLY_DIR/$WILDFLY_MODE/configuration/$WILDFLY_MODE.xml

[ -x /bin/systemctl ] && systemctl start $WILDFLY_SERVICE || service $WILDFLY_SERVICE start

echo "Done."