
These scripts handle the creation, deletion and expansion of docker swarm clusters on CenturyLink Cloud.

You can accomplish all these tasks with a single command. We have made the Ansible playbooks used to perform these tasks available [here](https://github.com/CenturyLinkCloud/adm-swarm-on-clc/blob/master/ansible/README.md).

## Change History

The v0.5 release included the following major changes:

- Integrated Load Balancing, i.e. Swarm services of type LoadBalancer now automatically get a public IP address routed to all workers in the cluster via the CenturyLink Cloud LB service.

For a detailed change history, please visit [the CenturyLink Cloud release notes page](https://github.com/CenturyLinkCloud/adm-swarm-on-clc/releases).

## Find Help

If you run into any problems or want help with anything, we are here to help. Reach out to us via any of the following ways:

- Submit a github issue
- Find us in the Docker Swarm Slack Community, channel #provider-centurylink
- Send an email to swarm AT ctl DOT io
- Visit [our website](https://www.ctl.io/swarm/)

## Clusters of VMs or Physical Servers, your choice.

- We support Docker Swarm clusters on both Virtual Machines or Physical Servers. If you want to use physical servers for the worker nodes, simple use the --worker_type=bareMetal flag.
- For more information on physical servers, visit: [https://www.ctl.io/bare-metal/](https://www.ctl.io/bare-metal/))
- Physical serves are only available in the VA1 and GB3 data centers.
- VMs are available in all 13 of our public cloud locations

## Requirements

The requirements to run this script are:
- A linux administrative host (tested on ubuntu and OSX)
- python 2 (tested on 2.7.11), including the -dev and -crypto packages
  - pip (installed with python as of 2.7.9)
- git
- A CenturyLink Cloud account with rights to create new hosts
- An active VPN connection to the CenturyLink Cloud from your linux host

## Script Installation

After you have all the requirements met, please follow these instructions to install this script.

1) Clone this repository and cd into it.

```shell
git clone https://github.com/CenturyLinkCloud/adm-swarm-on-clc
```

2) Install all requirements, including
- Ansible
- [CenturyLink Cloud SDK](https://github.com/CenturyLinkCloud/clc-python-sdk)
- Ansible Modules

```shell
sudo pip install -r requirements.txt
```

3) Create the credentials file from the template and use it to set your ENV variables

```shell
cp ansible/credentials.sh.template ansible/credentials.sh
vi ansible/credentials.sh
source ansible/credentials.sh
```

4) Grant your machine access to the CenturyLink Cloud network by using a VM inside the network or [ configuring a VPN connection to the CenturyLink Cloud network.](https://www.ctl.io/knowledge-base/network/how-to-configure-client-vpn/)


#### Script Installation Example: Ubuntu 14 Walkthrough

If you use an ubuntu 14, for your convenience we have provided a step by step
guide to install the requirements and install the script.

```shell
  # system
  apt-get update
  apt-get install -y curl git python python-dev python-crypto
  curl -O https://bootstrap.pypa.io/get-pip.py
  python get-pip.py

  # installing this repository
  mkdir -p ~home/swarm-on-clc
  cd ~home/swarm-on-clc
  git clone https://github.com/CenturyLinkCloud/adm-swarm-on-clc.git
  cd adm-swarm-on-clc/
  pip install -r requirements.txt

  # getting started
  cd ansible
  cp credentials.sh.template credentials.sh; vi credentials.sh
  source credentials.sh
```

## Cluster Creation

To create a new Docker Swarm cluster, simply run the swarm-up.sh script. A complete
list of script options and some examples are listed below.

```shell
export CLC_CLUSTER_NAME=[name of swarm cluster]
cd ./adm-swarm-on-clc
bash swarm-up.sh -c="$CLC_CLUSTER_NAME"
```

It takes about 15 minutes to create the cluster. Once the script completes, it
will output some commands that will help you setup docker on swarm mode on your machine to point to the new cluster.

When the cluster creation is complete, the configuration files for it are stored
locally on your administrative host, in the following directory

```shell
> CLC_CLUSTER_HOME=$HOME/.clc_swarm/$CLC_CLUSTER_NAME/
```


#### Cluster Creation: Script Options

```shell
Usage: swarm-up.sh [OPTIONS]
Create servers in the CenturyLinkCloud environment and initialize a Docker Swarm cluster
Environment variables
  CLC_CLUSTER_NAME (may be set with command-line option)
  CLC_V2_API_USERNAME (required)
  CLC_V2_API_PASSWD (required)


Most options (both short and long form) require arguments, and must include "="
between option name and option value. _--help_ does
not take arguments

     -h (--help)                   display this help and exit
     -c= (--clc_cluster_name=)     set the name of the cluster, as used in CLC group names
     -d= (--datacenter=)           VA1 (default)
     -m= (--worker_count=)         number of swarm worker nodes
     -mem= (--vm_memory=)          number of GB ram for each worker
     -cpu= (--vm_cpu=)             number of virtual cps for each worker node
     -storage= (--vm_storage=)     additional disk storage for each worker node (default 100GB)
     -t= (--worker_type=)          "standard" [default, a VM] or "bareMetal" [a physical server]
     -phyid= (--server_config_id=) if obtaining a bareMetal server, this configuration id
                                   must be set to one of:
                                      physical_server_20_core
                                      physical_server_12_core
                                      physical_server_4_core
     --network_id=                 vlan name to use for the created hosts. Uses
                                   default if not set. If network does not exist
                                   host creation will fail.
```

## Cluster Expansion

To expand an existing Kubernetes cluster, run the ```add-swarm-node.sh```
script. A complete list of script options and some examples are listed [[below]](####Cluster Expansion: Script Options).
This script must be run from the same host that created the cluster (or a host
that has the cluster artifact files stored in ```~/.clc_swarm/$cluster_name```).

```shell
cd ./adm-swarm-on-clc
bash add-swarm-node.sh -c="name_of_swarm_cluster" -m=2
```

#### Cluster Expansion: Script Options

```shell
Usage: add-swarm-node.sh [OPTIONS]
Create servers in the CenturyLinkCloud environment and add to an
existing CLC swarm cluster

Environment variables CLC_V2_API_USERNAME and CLC_V2_API_PASSWD must be set in
order to access the CenturyLinkCloud API

     -h (--help)                   display this help and exit
     -c= (--clc_cluster_name=)     set the name of the cluster, as used in CLC group names
     -m= (--worker_count=)         number of swarm worker nodes to add

```

## Cluster Deletion

There are two ways to delete an existing cluster:

1) Use our python script:

```shell
python delete_cluster.py --clc_cluster_name=clc_cluster_name --datacenter=DC1
```

2) Use the CenturyLink Cloud UI. To delete a cluster, log into the CenturyLink
Cloud control portal and delete the parent server group that contains the
Docker Swarm Cluster.

## Examples

Create a cluster with name of swarm_1, 1 manager node and 3 workers nodes (on physical machines), in VA1

```shell
 bash swarm-up.sh --clc_cluster_name=swarm_1 --worker_type=bareMetal --worker_count=3 --datacenter=VA1
```

Create a cluster with name of swarm_2, 1 manager node and 1 worker node with no additional disk storage, in VA1

```shell
 bash swarm-up.sh --clc_cluster_name=swarm_2 --vm_storage=0 --worker_count=1 --datacenter=VA1
```

Create a cluster with name of swarm_3, manager nodes on 3 VMs and 6 worker nodes (on VMs), in VA1

```shell
 bash swarm-up.sh --clc_cluster_name=swarm_3 --worker_type=standard --worker_count=6 --datacenter=VA1
```

Create a cluster with name of swarm_4, 1 manager node, and 10 worker nodes (on VMs) with higher mem/cpu, in UC1 on a particular network

```shell
bash swarm-up.sh --clc_cluster_name=swarm_4 --worker_type=standard --worker_count=10 --datacenter=UC1 --network_id=vlan_2200_10.141.200 -mem=6 -cpu=4
```

## Cluster Features and Architecture

We use the following to create the swarm cluster:

- Unbuntu 14.04
- Docker 1.9.1

## Optional add-ons

* Logging: We offer an integrated centralized logging ELK platform so that all
  docker logs get sent to the ELK stack. To install the ELK stack
  and configure the swarm to send logs to it, follow [the log
  aggregation documentation](https://github.com/CenturyLinkCloud/adm-swarm-on-clc/blob/master/log_aggregration.md). Note: We don't install this by default as
  the footprint isn't trivial.

## Cluster management

The tool for managing a swarm cluster is the command-line
utility ```docker```.

### Configuration files

Various configuration files are written into the home directory *CLC_CLUSTER_HOME* under
```.clc_swarm/${CLC_CLUSTER_NAME}``` in several subdirectories. You can use these files
to access the cluster from machines other than where you created the cluster from.

- ```config/```: Ansible variable files containing parameters describing the manager and worker hosts
- ```hosts/```: hosts files listing access information for the ansible playbooks
- ```ssh/```: SSH keys for root access to the hosts


## ```docker``` on swarm mode usage examples

There are a great many features of _docker_ on swarm mode. Here are a few examples

List existing nodes, stacks, services and more:

```shell
docker node ls
docker service ls
docker stack ls
```

## LoadBalancer integration.

Our Docker Swarm code includes definitions of CenturyLink Cloud as a provider, which includes integration of the CLC Load Balancer services. When a Docker Swarm service is defined as type LoadBalancer, a public IP address is automatically obtained and mapped to the service endpoint.


## What Docker Swarm features do not work on CenturyLink Cloud

These are the known items that don't work on CenturyLink cloud but do work on other cloud providers:

- At this time, there is no support for persistent storage volumes provided by
  CenturyLink Cloud. However, customers can bring their own persistent storage
  offering. We ourselves use Gluster.


## Ansible Files

If you want more information about our Ansible files, please [read this file](https://github.com/CenturyLinkCloud/adm-swarm-on-clc/blob/master/ansible/README.md)


## License
The project is licensed under the [Apache License v2.0](http://www.apache.org/licenses/LICENSE-2.0.html).
