## ![swarm.png](/home/david/Software/swarm-environment/resources/swarm.png "Swarm Icon") High Availability Cluster

This proyect aims to analyze and give an arquitecture solucition for a high availability cluster of a common 3 layer stack; composed by database, app and front-end. In order to achive that purpose it uses the following tools:

- __Ansible__ an open-source software provisioning.
- __CoreOS__ as base operative system. Which comes also with __docker__.
- __etcd__ a key-value store that comes also with CoreOS.
- __ceph__ a unified and distributed storage system.
	* _deploy scripts not finished yet_.
- __portainer.io__ a beautiful GUI to manage swarm clusters.
- __prometheus.io__ which which are also deployed:
	* __node-exporter__ exports system and node data to prometheus.
	* __dockerd-exporter__ exports docker related metrics to prometheus.
	* __alertmanager__ triggers alerts based on metrics.
	* __unsee__ GUI for alertmanager.
	* __grafana__ a powerfull metric visualization tool for everything above.
- __elasticsearch__ multitenant-capable full-text search engine.
	* __kibana__ this project comes with the OSS version.
	* __cerebro__ elasticsearch web admin tool.
	* __beats__ from elastic. They feed elasticsearch.
- __XtraDB Cluster__ a high availability MySQL clustering solution.
- __ProxySQL__ high performance MySQL proxy.
- __PHP-FPM__ a PHP FastCGI implementation.
- __WordPress__ a free and open-source content management system.
- __Nginx__ with modsecurity and other monitoring modules.
- __LetsEncrypt__ for free TLS certificates.
	* __certbot__ ACME client to expedite certificates.
	* __certbot-dns-route53__ cerbot plugin to challenge against Route53.
- _Route53_ and _S3_ (paid) clouded solutions for DNS and here used for backups.

### Cluster diagram

![swarm-cluster.png](/home/david/Software/swarm-environment/resources/swarm-cluster.png "Cluster diagram")

### Cluster overview

The cluster structure is designed as a 2x3x(1+2), with 3 diferentiated network layers. Traffic from outside internet is balanced using Route53 Routing Policies ("simple" for this project). It reaches the swarm _ingress_ network which routes traffic to the 2 nginx servers on the _frontnet_ overlay network. Theese two process the requests using php-fpm on _appnet_ to gather resources as needed. App servers in turn performs MySQL queries via ProxySQL to the XtraDB multi-master cluster located on the _dbnet_.

All overlay networks are created with `--opt encrypted` to enable data encryption.

_Etcd_ cluster is deployed on the app nodes (best 3 or 5 nodes).

_Ceph_ is used to create and mount 3 main volumes (database, configs/files and logs). Even though swarm manages some configs needed by containers, the configs volumes is intended to store as well static content and the main app sources. As part of a DRP (Disaster Recovery Plan) another ceph cluster may be configured on another provider/zone/dpc using rdb-mirroring.

Backups are taken and uploaded to S3 Glacier.

Monitoring services are playing arround the cluster. There are some like _node-exporter_, _dockerd-exporter_ or different _beats_ that must run on every node to collect metrics and logs. Whereas dashboards like _portainer_, _grafana_ or _cerebro_ reside on the app servers, accessibles through front-end _nginx_ nodes who are also responsible to deal with TLS end-user certificates.

_LetsEncrypt_, a free recognized certificate authority, is used together with _certbot_ to generate and renew end-user TLS certificates. _certbot-dns-route53_ ACME challenge method is preferred to automatically renew them.

### Folder structure

```
.
├── ansible
│   ├── hosts
│   ├── main.yml
│   ├── playbooks
│   │   ├── ceph.yml
│   │   ├── hardening.yml
│   │   ├── labels.yml
│   │   └── swarm.yml
│   ├── roles
│   │   ├── defunctzombie.coreos-bootstrap
│   │   └── githubixx.etcd
│   ├── run.sh
│   ├── tasks
│   │   ├── certs.yml
│   │   └── etcd.yml
│   └── templates
├── ceph
├── certs
├── elk
├── portainer
├── resources
├── route53
├── swarmprom
│   ├── alertmanager
│   ├── caddy
│   ├── dockerd-exporter
│   ├── grafana
│   ├── node-exporter
│   └── prometheus
└── xtradb-cluster
```

### Bootstraping the cluster

Ansible is the tool that will make the initial cluster bootstraping process. It automates the following tasks:

- Install _python_ and dependencies on each CoreOS host to be able to run ansible.
- Run the script located on `resources/boot.sh`.
- Generate locally a root CA and feed each host with appropriate certificates.
- Setup and run the etcd cluster.
- Setup and run the swarm cluster.
- Label each swarm node.
- Harden the docker daemon.

The very first step is to install python, pip and dependencies needed to run ansible on each CoreOS host. An ansible rol called [_defunctzombie.coreos-bootstrap_](https://github.com/defunctzombie/ansible-coreos-bootstrap) is used for this task. The rol is actually no longer mantained but despite some deprecation warnings and by updating the bundled-in pip binary, it does the job quite well.

`resources/boot.sh` is an all-in-one basic CoreOS bootstraping script that performs tasks like setting up `.ssh/authorized_keys` with the right public keys. Making some time-saving aliases. Install `ctop` (top-like interface for container metrics) and `gotop` (top-like interface written in go). Disables ssh root login. Creates a simple backup service managed by systemd that compresses volumes from docker and uploads them to S3. This script is inherited from a small not clustered instance, that's why optionally it can create and activate a swapfile for low ram provisioned machines.

Following next a locally root CA with certificates for each host is created by using the (also deprecated) tool `etcd-ca`. Here is important to know the private IP address of every host. Because it will use the X509 V3 certificate subject alternative name extension to indicate the DNS identifier and IP in each certificate. Hostname modifications and `/etc/hosts` resolutions are also automated with ansible. It is also good to know that certificates must include _serverAuth_ and _clientAuth_ on their extended key usage.

After that ansible will start to configure and launch the etcd cluster. Using a quite much tuned for this project role, named [_githubixx.etcd_](https://github.com/githubixx/ansible-role-etcd). The service will be managed by systemd on tree or five of the app servers using the script that CoreOS provides (`/usr/lib/coreos/etcd-wrapper`). After this an initial cluster health check can be performed by issuing `etcdctl cluster-health`. Ansible should have filled up the file `/etc/profile.d/01-etcd.sh` with environment variables to make `etcdctl` command work with certificates.

The coming task is the creation of the swarm cluster. You must have defined on your `hosts` file only one swarm-advertiser that will act as the first swarm node that will coordinate the rest for consensus. At this step the docker API port will be published using a `docker-tcp.socket` systemd unit on each host belonging to the group swarm-managers. It will also enable and restart the docker daemon to immediately use it by defining locally on your docker cli console the `DOCKER_HOST=<manager_ip>` environment variable.

Finally ansible will label each node on the cluster properly to be able to distribute dinamically all different containers. And the very end task is the hardening of the docker daemon, trying to implement all the things mentioned on `resources/hardening-docker.txt`.

_Right now some tweaks described on `resources/hardening-docker.txt` are not implemented due to dependencies that need to be sorted out first, like non-root containers/daemon. Other have been changed in favor of better control like the driver-logging (beats will catch it). And other are incompatible with docker in swarm mode, like live-restore._

### Spreading up monitoring services

#### Portainer

Portainer Community Edition software is a beatiful graphic web interface to easily build, manage and maintain the docker swarm cluster. From docker stacks to swarm secrets, it has the hability to show each container logs and even launch a web shell to get into each container. This repo provides a yml stack definition to launch it, located on `portainer/docker-compose.yml`. By simply running

```
docker stack up -c portainer/docker-compose.yml mng
```

It will deploy on the cluster publishing the port `9000`. The agent is created cluster-wide, meanwhile the UI launches 1 instance on an app node type. There is also the possibility to not deploy any angent and configure portainer to connect to any swarm manager.

#### Prometheus

Prometheus is an open-source monitoring and alerting solution with a very efficient storage, lots of integrations and ready to scale. The tool is used altogether with grafana and unsee. Grafana provides fancy charts and metric visualizations from the data collected by dockerd-exporter, node-exporter and cadvisor. The project here, based on the work by [stefanprodan](https://github.com/stefanprodan/swarmprom.git), comes with bundled in dashboards for visualizing the overall swarm nodes status, swarm services status and the prometheus itself.

Alertmanager is part of prometheus and allows you to trigger an alarm on different ways while defined metrics come out of their normal values. Adjust the configuration file on `swarmprom/alertmanager/conf/alertmanager.yml`. A slack example is provided.

And deploy it to swarm by issuing:

```
cd swarmprom
docker stack up -c docker-compose.yml stats
```

This stack exposes port `9090` for prometheus, `3000` for graphana, `9093` for alertmanager and `9094` for unsee (the dashboard for alertmanager).

#### Elasticsearch

The software on this stack is almost from [Elastic](https://www.elastic.co) and even though this project uses the `-oss` images, there is a paid version with more powerfull analysis features that has a trial period. Remove the `-oss` on the stack file to start the trial or login with your plan credentials. There is also a container that deploys [cerebro](https://github.com/lmenezes/cerebro), a simple and satisfying elasticsearch web admin tool.

Beats (filebeat, journalbeat and packetbeat) are small globally deployed containers that feed elasticsearch directly with logs from different areas. Filebeat collects data from log files like nginx access logs, mysql, or other auto-discovered files. Journalbeat follows the system's journald logs to point out possible problems like auditd logs (this is experimental and recently incorporated by elastic). And packetbeat can collect a huge amount of metadata from all your network.

This last beat must be deployed in a way that allows it to listen on the main node network interfaces, so `elk/deployPacketbeat.sh` is used instead the service commented out on the stack definition.

Deploy the stack by issuing:
```
cd elk
docker stack up -c docker-stack.yml logs
```

### Starting to provide

#### Percona XtraDB Cluster

XtraDB Cluster is the open source solution for scalable high availability MySQL clustering by Percona. Following is a table comparison with other similar software.

| Factors | Mysql on ceph RBD | Mysql Cluster (NBD) | Galera Cluster | Mysql Replication | Mysql on DRBD | Mysql Sharding |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
| Dataset largen than single host | yes | yes | no | no | no | yes |
| Table larger than single host | yes | yes | no | no | no | no |
| Reliance on dataset parallelism | yes | no | no | no | no | no |
| Fault-tolerant storage | yes | yes | yes | yes | yes | no |
| Read scaling | n nodes | 48 nodes | yes | yes | no | n nodes |
| write scaling | n nodes | 24 nodes | n node | 1 node | 1 node | n nodes |
| consistent writes | sync | sync | sync | async | sync | n/a |
| multi-master | no | yes | yes | no | no | no |

_Comment: in the past I've used Galera Cluster (see my [galera-cluster](https://github.com/daper/galera-cluster) repo). So I decided to give a try to XtraDB._

##### Benefits:

- When you execute a query, it is executed locally on the node. All data is available locally, no need for remote access.
- No central management. You can loose any node at any point of time, and the cluster will continue to function without any data loss.
- Good solution for scaling a read workload. You can put read queries to any of the nodes.

##### Drawbacks:

- Overhead of provisioning new node. When you add a new node, it has to copy the full data set from one of existing nodes. If it is 100GB, it copies 100GB.
- This cannot be used as an effective write scaling solution. There might be some improvements in write throughput when you run write traffic to 2 nodes versus all traffic to 1 node, but you cannot expect a lot. All writes still have to go on all nodes.
- You have several duplicates of the data, for 3 nodes you have 3 duplicates.

Deploy the stack of sql-proxy and xtradb cluster by issuing:
```
cd xtradb-cluster
docker stack up -c docker-compose.yml db
```

#### PHP-FPM

The app services will run on php-fpm using [this repository](https://github.com/daper/docker-alpine-php) I did 3 years ago (at the time of writing this) based on an alpine image. That builds different versions of php with php-fpm and many extensions.

_Note: a docker image based on that must be created and stored on the cluster's docker registry to deploy it globally._

```
docker service create --name php-fpm \
	--network appnet \
	--hostname '{{.Node.Hostname}}-php-fpm' \
	--mode global \
	--constraint 'node.labels.type == app' \
	daper/docker-alpine-php:7.1-tcp
```

#### Nginx

Nginx will be deployed as an alpine-based image stored in a docker registry inside the cluster. This will do the compilation of nginx itself with ModSecurity. Also WAF rules will be bundled in. Alongside the letsencrypt certificates.

_Note: this part is pending._

### Extras

- `resources/swarm-prune.sh`, script that creates a volatile service and performs `docker system prune -a -f --volumes` alongside the cluster.
- `resources/create-networks.sh`, script for creating the 3 (dbnet, appnet and frontnet) overlay networks that this cluster relies on.
- `resources/generate-certs.sh`, script for manually generate certificates for hosts.
- `resources/known_hosts.sh`, script that pings ssh for every host in ansible's hosts file.

> @author David Peralta <david@daper.email>
