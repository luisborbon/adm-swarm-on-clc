#!/bin/bash
set -e
# deploy docker swarm cluster on clc
#
# Examples:
#
# Make a cluster with default values:
# > bash swarm-up.sh
#
# Make a cluster with custom values (cluster of VMs)
# > bash swarm-up.sh --clc_cluster_name=swarm_vm101 --worker_type=standard --worker_count=6 --datacenter=VA1 --vm_memory=4 --vm_cpu=2
#
# Make a cluster with custom values (cluster of physical servers)
# > bash swarm-up.sh --clc_cluster_name=swarm_vm101 --worker_type=bareMetal --worker_count=4 --datacenter=VA1
#

# Usage info
function show_help() {
cat << EOF
Usage: ${0##*/} [OPTIONS]
Create servers in the CenturyLinkCloud environment and initialize a Kubernetes cluster
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
     -m= (--worker_count=)         number of kubernetes worker nodes
     -mem= (--vm_memory=)          number of GB ram for each worker
     -cpu= (--vm_cpu=)             number of virtual cps for each worker node
     -storage= (--vm_storage=)     additional disk storage for each worker node (default 100GB)
     -t= (--worker_type=)          "standard" [default, a VM], "hyperscale" [a VM] or "bareMetal" [a physical server]
     -phyid= (--server_config_id=) if obtaining a bareMetal server, this configuration id
                                   must be set to one of:
                                      physical_server_20_core
                                      physical_server_12_core
                                      physical_server_4_core
     -a= (--anti_affinity_name=)   if using hyperscale server, an existing anti-affinity policy can be specified
     --network_id=                 vlan name to use for the created hosts. Uses
                                   default if not set. If network does not exist
                                   host creation will fail.
EOF
}

function exit_message() {
    echo "ERROR: $1" >&2
    echo
    echo
    show_help
    exit 1
}

# default values before reading the command-line args
datacenter=VA1
vlan_id=False   # False => use default
worker_count=2
worker_type=standard
server_config_id=default
vm_memory=4
vm_cpu=2
vm_storage=100
skip_worker=False
async_time=7200
async_poll=5

for i in "$@"
do
case $i in
    -h|--help)
    show_help && exit 0
    shift # past argument=value
    ;;
    -c=*|--clc_cluster_name=*)
    CLC_CLUSTER_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--datacenter=*)
    datacenter="${i#*=}"
    shift # past argument=value
    ;;
    --network_id=*)
    vlan_id="${i#*=}"
    shift # past argument=value
    ;;
    -m=*|--worker_count=*)
    worker_count="${i#*=}"
    shift # past argument=value
    ;;
    -mem=*|--vm_memory=*)
    vm_memory="${i#*=}"
    shift # past argument=value
    ;;
    -cpu=*|--vm_cpu=*)
    vm_cpu="${i#*=}"
    shift # past argument=value
    ;;
    -storage=*|--vm_storage=*)
    vm_storage="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--worker_type=*)
    worker_type="${i#*=}"
    shift # past argument=value
    ;;
    -phyid=*|--server_config_id=*)
    server_config_id="${i#*=}"
    shift # past argument=value
    ;;
    -a=*|--anti_affinity_name=*)
    anti_affinity_name="${i#*=}"
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

if [[ ${worker_type} == "standard" ]] || [[ ${worker_type} == "hyperscale" ]]
then
  if [[ ${server_config_id} != "default" ]]
  then
    exit_message "server_config_id=\"${server_config_id}\" is not compatible with worker_type=\"${worker_type}\""
  fi
elif [[ ${worker_type} == "bareMetal" ]]
then
    true # do nothing, validate internally in ansible
else
  exit_message "worker type \"${worker_type}\" unknown"
fi

if [[ ${anti_affinity_name} != "" ]]
then
  if [[ ${worker_type} != "hyperscale" ]]
  then
    exit_message "anti_affinity_name=\"${anti_affinity_name}\" is not compatible with worker_type=\"${worker_type}\""
  fi
fi


CLC_CLUSTER_HOME=~/.clc_swarm/${CLC_CLUSTER_NAME}

mkdir -p ${CLC_CLUSTER_HOME}/hosts
mkdir -p ${CLC_CLUSTER_HOME}/config
created_flag=${CLC_CLUSTER_HOME}/created_on

cd ansible
if [ -e $created_flag ]
then
  echo "cluster file $created_flag already exists, skipping host creation"
else

  echo "Creating Docker Swarm Cluster on CenturyLink Cloud"
  echo "Writing local configuration files"

  cat <<CONFIG > ${CLC_CLUSTER_HOME}/config/manager_config.yml
clc_cluster_name: ${CLC_CLUSTER_NAME}
server_group: swarm-manager
server_group_tag: manager
datacenter: ${datacenter}
vlan_id: ${vlan_id}
server_count: 1
server_config_id: default
server_memory: 4
server_cpu: 2
skip_worker: True
assign_public_ip: False
async_time: 7200
async_poll: 5
anti_affinity_name:
CONFIG

  cat <<CONFIG > ${CLC_CLUSTER_HOME}/config/worker_config.yml
clc_cluster_name: ${CLC_CLUSTER_NAME}
server_group: swarm-worker
server_group_tag: worker
datacenter: ${datacenter}
vlan_id: ${vlan_id}
server_count: ${worker_count}
worker_type: ${worker_type}
server_config_id: ${server_config_id}
server_memory: ${vm_memory}
server_cpu: ${vm_cpu}
server_storage: ${vm_storage}
skip_worker: False
async_time: 7200
async_poll: 5
anti_affinity_name: ${anti_affinity_name}
CONFIG



  #### Part0
  echo "Part0a - Create local sshkey if necessary"
  ansible-playbook create-local-sshkey.yml \
     -e server_cert_store=${CLC_CLUSTER_HOME}/ssh

  echo "Part0b - Create parent group"
  ansible-playbook create-parent-group.yml \
      -e config_vars=${CLC_CLUSTER_HOME}/config/manager_config.yml

  #### Part1a
  echo "Part1a - Building out the infrastructure on CLC"

  # background these in order to run them in parallel
  pids=""

  { ansible-playbook create-manager-hosts.yml \
      -e config_vars=${CLC_CLUSTER_HOME}/config/manager_config.yml;
  } &
  pids="$pids $!"

  { ansible-playbook create-worker-hosts.yml \
      -e config_vars=${CLC_CLUSTER_HOME}/config/worker_config.yml;
  } &
  pids="$pids $!"

  # -----------------------------------------------------
  # a _wait_ checkpoint to make sure these CLC hosts were
  # created safely, exiting if there were problems
  # -----------------------------------------------------
  set +e
  failed=0
  ps $pids
  for pid in $pids
  do
    wait $pid
    exit_val=$?
    if [ $exit_val != 0 ]
    then
      echo "process $pid failed with exit value $exit_val"
      failed=$exit_val
    fi
  done

  if [ $failed != 0 ]
  then
    exit $failed
  fi
  set -e
  # -----------------------------------------------------

  # write timestamp into flag file
  date +%Y-%m-%dT%H-%M-%S%z > $created_flag

fi # checking [ -e $created_flag ]

#### verify access
ansible -i ${CLC_CLUSTER_HOME}/hosts -m shell -a uptime all

#### Part2
echo "Part2 - Install ansible galaxy roles"
ansible-galaxy install grycap.swarm

#### Part3
echo "Part3 - Setting up swarm"
ansible-playbook -i ${CLC_CLUSTER_HOME}/hosts install_swarm.yml \
    -e clc_cluster_name=${CLC_CLUSTER_NAME} \
    -e config_vars_manager=${CLC_CLUSTER_HOME}/config/manager_config.yml \
    -e config_vars_worker=${CLC_CLUSTER_HOME}/config/worker_config.yml

# @TODO: Update docker compose templates to install standard addons
#### Part4
# echo "Part4 - Installing standard addons"
# standard_addons='{"swarm_apps":["dashboard","monitoring"]}'
# ansible-playbook -i ${CLC_CLUSTER_HOME}/hosts deploy_swarm_applications.yml \
#      -e ${standard_addons}

cat <<MESSAGE

Cluster build is complete. To administer the cluster, access any manager and configure
the swarm with

  docker node ls

MESSAGE
