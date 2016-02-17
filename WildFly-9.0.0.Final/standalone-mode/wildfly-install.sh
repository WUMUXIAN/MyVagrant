
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
echo JBOSS_CONFIG=$WILDFLY_MODE-full.xml >> $WILDFLY_SERVICE_CONF
echo JBOSS_MODE=$WILDFLY_MODE >> $WILDFLY_SERVICE_CONF
fi
