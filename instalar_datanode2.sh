#!/bin/bash

HADOOP_VER="3.4.2"
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VER/hadoop-$HADOOP_VER.tar.gz"
JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
INSTALL_DIR="/usr/local/hadoop"
HADOOP_USER="hadoop"

echo ">>> 1. Configurando el directorio telefónico (/etc/hosts)..."
# IPs de Tailscale
cat <<EOT >> /etc/hosts

# Clúster Hadoop Big Data
100.122.144.60    namenode
100.109.255.107   datanode1
100.93.153.97     datanode2
EOT

echo "Instalación de dependencias"
apt update
apt install -y openjdk-17-jdk ssh pdsh wget tar curl

if ! id "$HADOOP_USER" &>/dev/null; then
    useradd -r -m -d /home/$HADOOP_USER -s /bin/bash $HADOOP_USER
fi

chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER

mkdir -p /home/$HADOOP_USER/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCz1V4v1AkTye4uCO31ZiCCLvqB6tByt0O5JKR1NPb/DcuPw9mYZvXgOPxTKHOMfuWa2gr0ielyq2aeAjdVipcs5ZEcQbyi0K6IVVB/tzKDI+nk/5SUZC8omt+o0LNlKzSL1/oQfAv5tWXUIWY8Od3lDnjUwIOpLK/6Ro4mG7LpNXyCQoVZj/qVoKQLVPqVa3rrSaEvNtSX8jUB/UOeqnSBjgAASs+QD7cRr4kJ5rtWojSsavPjYwP5EMjn+ZjihL9RnGGhZKI1dufTHDYXLPS1t/yHHGXczdPHBgHndqu1Fel11CDJ37QfH3yO1NPKEjIAH3awhTP60HUjcf0ksUF8eeKlw4OibOPCJyedEz/Lwc3Yvk/1mhxVsCByLZxDNkTPk4EEbPoabP/Yd9gCvIvzQEyUVbB1Rtmrs7dM/1Zt44w+VJ8kxXxkdyhFPTxm48wuBpwGh6eFyS5MRKTjQUNGU0ezUfgh0d17G9oZY/d5M+GxAAPq75Q041J4SCYuqeM= hadoop@Nitro-AN515-58" >> /home/$HADOOP_USER/.ssh/authorized_keys
chmod 700 /home/$HADOOP_USER/.ssh
chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys
chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER/.ssh
sudo -u $HADOOP_USER bash -c "ssh-keyscan -H namenode >> /home/$HADOOP_USER/.ssh/known_hosts 2>/dev/null"

rm -rf $INSTALL_DIR
cd /tmp
wget -4 -nc $HADOOP_URL
tar -xzf hadoop-$HADOOP_VER.tar.gz
mv hadoop-$HADOOP_VER $INSTALL_DIR
chown -R $HADOOP_USER:$HADOOP_USER $INSTALL_DIR

BASHRC="/home/$HADOOP_USER/.bashrc"
sed -i '/HADOOP/d' $BASHRC
sed -i '/JAVA_HOME/d' $BASHRC
cat <<EOT >> $BASHRC
export JAVA_HOME=$JAVA_HOME_PATH
export HADOOP_HOME=$INSTALL_DIR
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_HOME/lib/native"
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export PDSH_RCMD_TYPE=ssh
EOT
chown $HADOOP_USER:$HADOOP_USER $BASHRC

echo "export JAVA_HOME=$JAVA_HOME_PATH" > $INSTALL_DIR/etc/hadoop/hadoop-env.sh
echo "export HADOOP_OS_TYPE=dot_ham_mode" >> $INSTALL_DIR/etc/hadoop/hadoop-env.sh

cat > $INSTALL_DIR/etc/hadoop/core-site.xml <<EOL
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://namenode:9000</value>
    </property>
</configuration>
EOL

mkdir -p $INSTALL_DIR/hdfs/datanode
chown -R $HADOOP_USER:$HADOOP_USER $INSTALL_DIR/hdfs

cat > $INSTALL_DIR/etc/hadoop/hdfs-site.xml <<EOL
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file://$INSTALL_DIR/hdfs/datanode</value>
    </property>
</configuration>
EOL

cat > $INSTALL_DIR/etc/hadoop/mapred-site.xml <<EOL
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOL

cat > $INSTALL_DIR/etc/hadoop/yarn-site.xml <<EOL
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOL

