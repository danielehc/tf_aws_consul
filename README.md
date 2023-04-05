# Scenario Provision Tool

**Only TL;DR Version is available for now :(** 

> **WARNING:** the script is under development currently so some configurations might not work. Do not test on production environments.

## What does it do?

Provides useful tools and templates to deploy a Consul GetStarted scenarios on VMs.

## How do I use it?

Deploy infrastructure:

```
cd ./infrastructure
```

```
terraform init
```

```
terraform plan
```

```
terraform apply
```

The deploy prints some output that is helpful to interact with the scenario:

```plaintext
connection_string = "ssh -i certs/id_rsa.pem admin@35.88.242.132"
ip_api = "34.217.68.40"
ip_bastion = "35.88.242.132"
ip_consul = [
  "54.185.216.179",
]
ip_db = "35.93.156.123"
ip_fe = "34.216.232.254"
ip_nginx = "54.185.18.73"
remote_ops = "export BASTION_HOST=35.88.242.132"
ui_consul = "https://54.185.216.179:8443"
ui_grafana = "http://35.88.242.132:3000"
ui_hashicups = "http://54.185.18.73"
ui_loki = "http://35.88.242.132:3100"
ui_mimir = "http://35.88.242.132:9009"
```

Use:

* `connection_string` to SSH into the Bastion Host

* use `remote_ops` in combination with the `ops/provision.sh` script to test scenario from the local node.

## Repository structure

The repository is divided in three main folders:

* assets
* infrastructure
* ops

### Assets Folder

Contains the shared assets you need during the scenario operations.

### Infrastructure Folder
Contains the TF code to deploy the infrastructure.

It will be split across different cloud provider in the future. For now is AWS only.

### Ops Folder
Contains the `provision.sh` tool and the scenario definition files under the folder `scenarios/`


## Test remote operations

Once the infrastructure deploy completed:

1. Copy the `remote_ops` value
    ```
    terraform output -raw remote_ops
    ```
2. Move into the ops folder
    ```
    cd ../ops
    ```
3. Export the variable `BASTION_HOST` defined by the TF output
    ```
    export BASTION_HOST=35.88.242.132
    ```
4. Try deploy a scenario
    ```
    ./provision.sh operate 01
    ```
    > `01` refers to the name of the scenario and uses as a reference the name of the folders under `ops/scenarios`. The script will merge all the files under the scenario together in a single script that will be then copied and executed remotely on the BASTION_HOST.