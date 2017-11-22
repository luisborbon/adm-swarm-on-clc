
## More about the ansible playbooks

For those interested in the ansible files themselves, here is a little more information about them.

### Creating virtual hosts (part 1)

Three playbooks are used to create hosts
- create-worker-hosts.yml
- create-manager-hosts.yml

Each of these playbooks uses the _clc_provisioning_ role, runs on localhost and
makes http calls to the CenturyLink Cloud API.

The process writes several configuration files to the cluster home directory, found
at ~/.clc_swarm/${CLC_CLUSTER_NAME}  The configuration files _config/manager_config.yml_
and _config/worker_config.yml_ contain the cluster name and the VM provisioning
information.

### Provisioning the cluster (parts 2-4)

#### Installing Kubernetes

In part 3, the _kube-up.sh_ script calls two playbooks to install swarm, with
differerent configurations for the manager and worker nodes.

`ansible-playbook  create-worker-hosts.yml \
    -e config_vars=${CLC_CLUSTER_HOME}/config/worker_config.yml

ansible-playbook  create-manager-hosts.yml \
    -e config_vars=${CLC_CLUSTER_HOME}/config/manager|_config.yml`


#### Running Docker Swarm applications

In part 4, the _swarm-up.sh_ script calls a playbook to deploy some of the standard
addons

This playbook can be used outside of the script as well to install additional
applications.  There are templates in the role _swarm-manifest_ already
written for several applications.  These can be applied with the
_deploy_swarm_applications.yml_ playbook (using the ansible json-syntax for
a command-line list)

```
app_list='{"swarm_apps":["guestbook-all-in-one","swarm-ui"]}
ansible-playbook -i hosts-${CLC_CLUSTER_NAME}  -e ${app_list}  deploy_swarm_applications.yml
```
