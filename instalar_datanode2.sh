#!/bin/bash

# ==========================================
# SCRIPT MAESTRO - CONFIGURACIÓN DATANODE 2
# ==========================================

HADOOP_VER="3.4.2"
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VER/hadoop-$HADOOP_VER.tar.gz"
JAVA_HOME_PATH="/usr/lib/jvm/java-11-openjdk-amd64"
INSTALL_DIR="/usr/local/hadoop"
HADOOP_USER="hadoop"

echo ">>> 1. Configurando el directorio telefónico (/etc/hosts)..."
# Inyectando las IPs de Tailscale de todo el clúster
cat <<EOT >> /etc/hosts

# Clúster Hadoop Big Data (Red Tailscale)
100.122.144.60    namenode
100.109.255.107   datanode1
100.114.151.26    datanode2
EOT

echo ">>> 2. Instalando dependencias (Java 11, SSH, etc)..."
apt-get update
apt-get install -y openjdk-11-jdk ssh pdsh wget tar curl

echo ">>> 3. Creando usuario '$HADOOP_USER'..."
if ! id "$HADOOP_USER" &>/dev/null; then
    useradd -r -m -d /home/$HADOOP_USER -s /bin/bash $HADOOP_USER
fi

echo ">>> 4. Autorizando acceso directo al Namenode (Acer)..."
mkdir -p /home/$HADOOP_USER/.ssh
# Inyectando la llave pública del coordinador
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCz1V4v1AkTye4uCO31ZiCCLvqB6tByt0O5JKR1NPb/DcuPw9mYZvXgOPxTKHOMfuWa2gr0ielyq2aeAjdVipcs5ZEcQbyi0K6IVVB/tzKDI+nk/5SUZC8omt+o0LNlKzSL1/oQfAv5tWXUIWY8Od3lDnjUwIOpLK/6Ro4mG7LpNXyCQoVZj/qVoKQLVPqVa3rrSaEvNtSX8jUB/UOeqnSBjgAASs+QD7cRr4kJ5rtWojSsavPjYwP5EMjn+ZjihL9RnGGhZKI1dufTHDYXLPS1t/yHHGXczdPHBgHndqu1Fel11CDJ37QfH3yO1NPKEjIAH3awhTP60HUjcf0ksUF8eeKlw4OibOPCJyedEz/Lwc3Yvk/1mhxVsCByLZxDNkTPk4EEbPoabP/Yd9gCvIvzQEyUVbB1Rtmrs7dM/1Zt44w+VJ8kxXxkdyhFPTxm48wuBpwGh6eFyS5MRKTjQUNGU0ezUfgh0d17G9oZY/d5M+GxAAPq75Q041J4SCYuqeM= hadoop@Nitro-AN515-58" >> /home/$HADOOP_USER/.ssh/authorized_keys
chmod 700 /home/$HADOOP_USER/.ssh
chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys
chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER/.ssh

# Confiando en la firma del namenode para evitar el prompt (yes/no)
sudo -u $HADOOP_USER bash -c "ssh-keyscan -H namenode >> /home/$HADOOP_USER/.ssh/known_hosts 2>/dev/null"

echo ">>> 5. Descargando e instalando Hadoop $HADOOP_VER..."
if [ ! -d "$INSTALL_DIR" ]; then
    cd /tmp
    wget -nc $HADOOP_URL
    tar -xzf hadoop-$HADOOP_VER.tar.gz
    mv hadoop-$HADOOP_VER $INSTALL_DIR
fi
chown -R $HADOOP_USER:$HADOOP_USER $INSTALL_DIR

echo ">>> 6. Configurando variables de entorno (.bashrc)..."
BASHRC="/home/$HADOOP_USER/.bashrc"
if ! grep -q "HADOOP_HOME" $BASHRC; then
    cat <<EOT >> $BASHRC
# Variables de Hadoop y Java
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
fi

echo ">>> 7. Configurando archivos XML de Hadoop..."
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

# Creando solo la carpeta del trabajador (datanode)
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

echo "======================================================"
echo "¡DATANODE 2 CONFIGURADO AL 100%!"
echo "Tu Namenode ya tiene acceso directo a esta máquina."
echo "======================================================"
