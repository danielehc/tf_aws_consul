# Consul Modular Scenario

Modular lab to spin-up a Consul datacenter using custom [Docker][docker] images.

<div style="background-color:#fcf6ea; color:#866d42; border:1px solid #f8ebcf; padding:1em; border-radius:3px; margin:24px 0;">
  <p><strong>Warning:</strong> The environment is not intended for production use. It is intended to mimic the behavior of a VM with a container and build test environments to test Consul functionalities without the overhead of deploying a full VM.
</p></div>


## Usage

All the functionalities are built around the `provision.sh` script.


### Spin-up scenario

```
./provision.sh scenario 00
```

The script will locate the scenario folder based on the parameter.

In the scenario folder will locate a script named `spin_infrastructure.sh` that will contain instructions to deploy the necessary container.

After that it will locate all files starting with two digits, concatenate them, copy them on the `operator` container and run the script.

Final state for scenario 00:

```plaintext
CONTAINER ID   IMAGE                                   COMMAND                  CREATED             STATUS             PORTS                                                 NAMES
5126a000b58f   danielehc/hashicups-database:latest     "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour   5432/tcp                                              db
e8fbd2a54993   danielehc/hashicups-api:latest          "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour   8080/tcp                                              api
f9f67a6ef340   danielehc/hashicups-frontend:latest     "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour   3000/tcp                                              frontend
a6299733d5ed   danielehc/hashicups-nginx:latest        "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour   80/tcp                                                nginx
d8b477d9f64a   danielehc/instruqt-base-consul:latest   "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour                                                         consul
2b76b4822a27   danielehc/instruqt-base-consul:latest   "/usr/bin/tini -- /e…"   About an hour ago   Up About an hour                                                         operator

```


### Test solution (BETA)

```
./provision.sh solve 00
```

The script will find a file named `solve_scenario.sh` inside the scenario folder, copy it to the `operator` container and execute it.


### Clean scenario

```
./provision.sh clean
```


### Build images (BETA)

The scenarios are based on custom Docker images. It is possible to rebuild them using:

```
./provision.sh build
```

<div style="background-color:#fcf6ea; color:#866d42; border:1px solid #f8ebcf; padding:1em; border-radius:3px; margin:24px 0;">
  <p><strong>Warning:</strong> The build uses <b>danielehc</b> as Docker repository and is not yet fully tested for the possibility to override that value. If you want to build you own images it is suggested you change the individual Makefiles present in each subfolder of the <b>images</b> folder.
</p></div>


<!--
Temporary architecture image:

![Temporary Arch](https://raw.githubusercontent.com/hashicorp-demoapp/hashicups-setups/main/docker-compose-consul/overview.png)


 ## Usage examples

You can test the scenario by running:

```shell-session
export DOCKER_REPOSITORY=your-repo && \
    ./provision.sh build_only && \
    ./provision.sh && \
    ./provision.sh operate
```

inside the repository root.

The command will:
* Define the Docker repository to use for building images (`export DOCKER_REPOSITORY=your-repo`)
* Build all needed images locally without pushing to DockerHub (`./provision.sh build_only`)
* Provision the containers according to configuration (`./provision.sh`)
* Configure and deploy Consul on the containers (`./provision.sh operate`)

Read the following sections to more details on what the script does.

### Docker image build 

The folder `images` contains the Dockerfile definition for all the containers 
needed by the scenario.

* `base` - Used by Consul servers, Vault server and Operator node
* `hashicups-<service-name>` - Created from `base` adds necessary configurations
for the service app to run.

### Container naming conventions

* Consul servers will be named `consul-server-${DATACENTER}-${NUMBER}`
* Consul clients hosting services will be named `svc-${DATACENTER}-${SERVICE}`

## Configure scenario

The file `ops/00_global_vars.env` contains the variables useful to tune the 
scenario configuration.

The file is used both in the infrastructure provision and in the deploy so it 
creates consistency in the outcome.

### Main configuration parameters

* `SERVER_NUMBER` (default `3`) - Number of servers to spin up per datacenter
* `DOMAIN` (default `consul`) - Cluster domain
* `PRIMARY_DATACENTER` (default `dc1`) - The name of the primary datacenter

### Datacenter number

* `DATACENTERS` (array) - An array of strings. Each string defines a datacenter name.
For each string in the array the script will create `SERVER_NUMBER` containers and
configure them as Consul servers in the datacenter named as the string.

By default the first value of the array should match `PRIMARY_DATACENTER` value.

**Example:** If `DATACENTERS=("dc1" "dc2")` then the script will create 6 Consul container.
3 named `consul-server-dc1-x` (with `1` <= `x` <= `${SERVER_NUMBER}`)
3 named `consul-server-dc2-x` (with `1` <= `x` <= `${SERVER_NUMBER}`)

<div style="background-color:#eff5ff; color:#416f8c; border:1px solid #d0e0ff; padding:1em; border-radius:3px; margin:24px 0;">
  <p><strong>Note:</strong> All the datacenters created will automatically be federated using WAN federation
</p></div>

### Scenario services - Still not completely defined

* `SERVICES` (array) - An array of strings. Each string defines a service name.
For each string in the array the script will create a container named 
`svc-${DATACENTER}-${SERVICE}`. The same services are created in **ALL** 
datacenters mentioned by the `DATACENTERS` variable.


* `SVC_MATCH_IMAGE_NAME=true` - If set to `true` the script will use Docker images 
with the same name of the service to create the environment. If set to `false` 
the `base` image will be used.

* `START_APPS=false` - If set to `true` the script will start the app on the clients.
This is used in case you don't want to deploy a specific application and are using
the `fake-service` binary provided by the `base` image.

### Mesh elements - Still not completely defined

* `MESH_ELEMENTS` (array) - Still not completely defined

## Spin-up environment

```shell-session
./provision.sh
```

Spins up containers for:

* Operator - Simulates a bastion host and is the node that runs all the commands that are necessary to complete the scenario setup
* [Vault][vault] - Used to generate TLS certificates for Consul datacenters
* [Consul][consul] servers
* Services
* Mesh components (Consul gateways) **Still under deployment**

You can verify the containers that are running after the script completes with:

```shell-session
docker ps -q --filter label=tag=instruqt \
    | xargs -n 1 docker inspect \
        --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' \
    | sed 's/ \// /' | sort -V
```

Example output: 

```log
172.20.0.2 vault
172.20.0.3 operator
172.20.0.4 consul-server-dc1-1
172.20.0.5 consul-server-dc1-2
172.20.0.6 consul-server-dc1-3
172.20.0.7 svc-dc1-frontend
172.20.0.8 svc-dc1-payments
172.20.0.9 svc-dc1-product-api
172.20.0.10 svc-dc1-product-api-db
172.20.0.11 svc-dc1-public-api
...
```

## Execute scenario

```shell-session
./provision.sh operate
```

The command combines all the files in the `./ops` folder into a single script, 
copies it into the `operator` container and runs it.

```shell-session
for i in `find ops/*` ; do
    cat $i >> ${ASSETS}scripts/operate.sh
done

chmod +x ${ASSETS}scripts/operate.sh

# Copy script to operator container
docker cp ${ASSETS}scripts/operate.sh operator:/home/app/operate.sh

# Run script
# docker exec -it operator "chmod +x /home/app/operate.sh"
docker exec -it operator "/home/app/operate.sh"
```

The idea is to help development of complex scenarios in a sequential form and by 
splitting long procedures into more manageable scripts containing only a clear 
subset of actions.

## Instruqt compatibility

The script is deployed to have a testbed for Consul advanced scenarios but also 
as a kick-off for the creation of [Instruqt][instruqt] scenarios.

The scripts use the internal Docker DNS to address containers but, if running in 
Instruqt uses the pre-populated `INSTRUQT_PARTICIPANT_ID` environment variable to
understand if the scenario is running on a self-hosted environment or in an 
Instruqt sandbox.

## Scenario files

During the scenario creation the script generates some files needed for the Consul
agent configuration, some to store secrets (that in a production environment should 
be stored in a safe location), and some other files that are used during the provision.

### Assets

Once the main scenario completed you can view the files created using:

```shell-session
docker exec -it operator /bin/bash -c "ls -1 /home/app/assets/"
```

### Logs

The scenario produces some logs (and will produce more of them in future versions).

To visualize the available logs:

```shell-session
docker exec -it operator /bin/bash -c "ls -1 /home/app/logs"
```

#### Notable log files

* `certificates.log` - All certificates generated for the scenario in readable format
* `files_created.log` - A summary of the different files created by the different sections

## Clean local files

### Clean environment

Stops and removes the containers used by the environment.

```
./provision.sh clean
```

### Delete Docker images

If you do not have other Docker images created locally you can remove the 
created ones with the following command.

```
docker rmi -f $(docker images -q <your-repo>/*)
```
-->

[vault]:https://www.vaultproject.io
[consul]:https://www.consul.io/
[envoy]:https://www.envoyproxy.io/
[docker]:https://www.docker.com/
[instruqt]:https://play.instruqt.com/ 