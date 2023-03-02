# Consul on AWS EC2 with terraform

## Scenario 0 - HashiCups


1. Create SSH keys for the environment
    ```sh
    cd certs
    ```
    ```sh
    ssh-keygen -t rsa -b 4096
    ```
1. Initialize Terraform
    ```
    terraform init
    ```
1. Check resources being created
    ```
    terraform plan
    ```
1. Apply Terraform plan
    ```
    terraform apply
    ```
