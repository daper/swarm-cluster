#!/bin/sh

HOME=/home/core
USER=$(basename $HOME)

# AWS credentials for CloudWatch Logs ans S3 backups.
AWS_BACKUP_BUCKET=""
AWS_ACCESS_KEY=""
AWS_SECRET_KEY=""
AWS_REGION="eu-west-1"

# Extended RegExp to filter which volumes are backed up by name.
# Leave as is to backup everything.
BKP_VOLUME_FILTER=""

if [ ! -d $HOME/.ssh ]; then
	mkdir -p $HOME/.ssh
	chmod 700 $HOME/.ssh
	chown $USER:$USER $HOME/.ssh
	echo "[c] $HOME/.ssh"
fi

if [ ! -f $HOME/.ssh/authorized_keys ]; then
	echo "<PUBLIC_SSH_KEY>" > $HOME/.ssh/authorized_keys
	chown $USER:$USER $HOME/.ssh/authorized_keys
	chmod 600 $HOME/.ssh/authorized_keys
	echo "[c] $HOME/.ssh/authorized_keys"
fi

if [ -L $HOME/.bashrc ]; then
	rm $HOME/.bashrc
	cp -f /usr/share/skel/.bashrc $HOME/
	chown $USER:$USER $HOME/.bashrc
	chmod 600 $HOME/.bashrc
	echo "[c] $HOME/.bashrc"
	cat >> $HOME/.bashrc <<-EOT
		if [ -f ~/.bash_aliases ]; then
		        . ~/.bash_aliases
		fi
	EOT
	echo "[e] $HOME/.bashrc"
fi

if [ ! -f $HOME/.bash_aliases ]; then
	cat > $HOME/.bash_aliases <<-EOT
		alias dc=docker-compose
		alias toolbox='toolbox getty -nl /bin/sh 0 /dev/console'
	EOT
	chown $USER:$USER $HOME/.bash_aliases
	chmod 600 $HOME/.bash_aliases
	echo "[c] $HOME/.bash_aliases"
fi

if [ ! -f $HOME/.toolboxrc ]; then
	echo "TOOLBOX_DOCKER_IMAGE=alpine" > $HOME/.toolboxrc
	chown $USER:$USER $HOME/.toolboxrc
	chmod 600 $HOME/.toolboxrc
	echo "[c] $HOME/.toolboxrc"
fi

if [ ! -d /opt/bin ]; then
	mkdir -p /opt/bin
	echo "[c] /opt/bin"
fi

if [ ! -f /opt/bin/docker-compose ]; then
	curl -s -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /opt/bin/docker-compose
	chown root:root /opt/bin/docker-compose
	chmod +x /opt/bin/docker-compose
	echo "[c] /opt/bin/docker-compose"
fi

if [ ! -f /opt/bin/ctop ]; then
	curl -s -L https://github.com/bcicen/ctop/releases/download/v0.7/ctop-0.7-linux-amd64 -o /opt/bin/ctop
	chown root:root /opt/bin/ctop
	chmod +x /opt/bin/ctop
	echo "[c] /opt/bin/ctop"
fi

if [ ! -f /opt/bin/gotop ]; then
	curl -sL https://github.com/cjbassi/gotop/releases/download/2.0.0/gotop_2.0.0_linux_amd64.tgz \
	| tar zxvC /opt/bin gotop
	chown root:root /opt/bin/gotop
	chmod +x /opt/bin/gotop
	echo "[c] /opt/bin/gotop"
fi

if grep -xq "PermitRootLogin yes" /etc/ssh/sshd_config; then
	sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
	systemctl restart sshd
	echo "[e] sshd"
fi

# if [ ! -f /swapfile.swap ]; then
# 	mkdir -p /var/vm
# 	fallocate -l 2g /var/vm/swapfile
# 	chmod 600 /var/vm/swapfile
# 	mkswap /var/vm/swapfile
# 	echo "[c] swapfile"

# 	cat > /etc/systemd/system/var-vm-swapfile.swap <<-EOT
# 		[Unit]
# 		Description=Turn on swap

# 		[Swap]
# 		What=/var/vm/swapfile

# 		[Install]
# 		WantedBy=multi-user.target
# 	EOT
# 	systemctl enable --now var-vm-swapfile.swap
# 	echo "[e] swapfile.swap"
# fi

if [ ! -f /root/.aws/credentials ]; then
	mkdir -p /root/.aws
	cat > /root/.aws/credentials <<-EOT
		[default]
		aws_access_key_id=$AWS_ACCESS_KEY
		aws_secret_access_key=$AWS_SECRET_KEY
		region=$AWS_REGION
	EOT
	echo "[c] AWS Credentials"
fi

if [ ! -f /root/backup.sh ]; then
	wget "https://gist.githubusercontent.com/daper/bde5ef75f9430ce800e37f62583a478d/raw/a840d612d979a4f50876d5b4927570d854720349/backup.sh" \
		-O /root/backup.sh
	chown root:root /root/backup.sh
	chmod ug+x /root/backup.sh
	sed -i "s/^SCRIPT=.+$/SCRIPT=\/root\/backup.sh/" /root/backup.sh
	sed -i "s/^BUCKET_NAME=.+$/BUCKET_NAME=$AWS_BACKUP_BUCKET/" /root/backup.sh
	cat >> /root/backup.sh <<-EOT
		dest_folder="\$(hostname)@\$(curl -s https://ipecho.net/plain)"
		volumes=\$(docker volume ls -f 'dangling=false' -q | grep -E "\$BKP_VOLUME_FILTER")

		for volume in \$volumes; do
		  echo "[i] Procesing \$volume..." \
		  && local_bkp_path=/tmp \
		  && path=\$(docker volume inspect \$volume | grep Mountpoint | sed -n 's/.*"\(\/.*\)",/\1/p') \
		  && echo -e "\t=> \$path" \
		  && cd \$path \
		  && tar_name="\$(date +'%F')-\${volume}.tar.bz2" \
		  && echo -e "\t=> compressing" \
		  && tar cJSpf "\$local_bkp_path/\$tar_name" .
		  echo -e "\t=> uploading" \
		  && uploadParts "\$local_bkp_path/\$tar_name" "\$dest_folder/\$tar_name" \
		  && echo -e "\t=> done" \
		  && rm "\$local_bkp_path/\$tar_name"
		done
	EOT
	echo "[c] backup.sh"
fi

if [ ! -f /etc/systemd/system/backup.service ]; then
	cat > /etc/systemd/system/backup.service <<-EOT
		[Unit]
		Description=Backups docker volumes.

		[Service]
		Type=oneshot
		ExecStart=/root/backup.sh
	EOT
	echo "[c] backup.service"
fi

if [ ! -f /etc/systemd/system/backup.timer ]; then
	cat > /etc/systemd/system/backup.timer <<-EOT
		[Unit]
		Description=Run backup.service every sunday.

		[Timer]
		OnCalendar=Sun *-*-* 4:00:00

		[Install]
		WantedBy=multi-user.target
	EOT
	systemctl daemon-reload
	systemctl enable backup.timer
	systemctl start backup.timer
	echo "[c] backup.timer"
fi
