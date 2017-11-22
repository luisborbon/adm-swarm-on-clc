#!/bin/bash
set -e
# Add node to existing CLC swarm cluster

# Usage info
function show_help() {
cat << EOF
Usage: ${0##*/} [OPTIONS]
Create servers in the CenturyLinkCloud environment and add to an
existing CLC swarm cluster

Environment variables CLC_V2_API_USERNAME and CLC_V2_API_PASSWD must be set in
order to access the CenturyLinkCloud API

     -h (--help)                   display this help and exit
     -c= (--clc_cluster_name=)     set the name of the cluster, as used in CLC group names
     -m= (--worker_count=)         number of swarm worker nodes to add
EOF
}

function exit_message() {
    echo "ERROR: $1" >&2
    exit 1
}

# set count=1 as default
worker_count=1

for i in "$@"
do
case $i in
    -h|--help)
    show_help && exit 0
    ;;
    -c=*|--clc_cluster_name=*)
    CLC_CLUSTER_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -m=*|--worker_count=*)
    worker_count="${i#*=}"
    shift # past argument=value
    ;;
    *)
    echo "Unknown option: $1"
    echo
    show_help
  	exit 1
    ;;
esac
done

if [ -z ${CLC_V2_API_USERNAME:-} ] || [ -z ${CLC_V2_API_PASSWD:-} ]
  then
  exit_message 'Environment variables CLC_V2_API_USERNAME, CLC_V2_API_PASSWD must be set'
fi

if [ -z ${CLC_CLUSTER_NAME} ]
  then
  exit_message 'Cluster name must be set with either command-line argument or as environment variable CLC_CLUSTER_NAME'
fi

CLC_CLUSTER_HOME=~/.clc_swarm/${CLC_CLUSTER_NAME}
hosts_dir=${CLC_CLUSTER_HOME}/hosts/
config_dir=${CLC_CLUSTER_HOME}/config/

if [ ! -d ${config_dir} ]
  then
  exit_message "Configuration directory ${config_dir} not found"
fi

cd ansible

# set the _add_nodes_ variable
ansible-playbook create-worker-hosts.yml \
  -e add_nodes=1 \
  -e worker_count=$worker_count \
  -e config_vars_manager=${CLC_CLUSTER_HOME}/config/manager_config.yml \
  -e config_vars_worker=${CLC_CLUSTER_HOME}/config/worker_config.yml

#### verify access
echo ansible -i $hosts_dir -m shell -a uptime all
ansible -i $hosts_dir -m shell -a uptime all

echo $hosts_dir
#### Part3
echo "Part3 - Setting up swarm"
# ansible-playbook install_swarm.yml -i $hosts_dir \
#    -e config_vars_manager=${CLC_CLUSTER_HOME}/config/manager_config.yml \
#    -e config_vars_worker=${CLC_CLUSTER_HOME}/config/worker_config.yml \
#    --limit swarm-node
