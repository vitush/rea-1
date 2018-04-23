## REA task 
    
### Idea: 
Run the application in ECS container using CloudFormation for deployment.
See `./documentation/infrastructure-diagram.png`
    
This approach provides a unified scalable way to deploy stateless applications.
Usage of dockers ensures that the result of deployment would be the same all the time.

#### Security:
- The Application is running in ECS instances in private Network 
- Access to instances is protected by and are protected AWS Security Group.       
- The Application is running inside the Docker container that provides the additional level of security.
- Access to LoadBalancer is protected by AWS Security Group.       
    
#### Scalability:
- You can easily scale up and down the application using Auto-scalable Group
based on different triggers ( HTTP-error-500, CPU-load .. etc..)

#### Availability:
- The application can be launched in two or more nodes and in different availability zones.

#### Deployment:      
Selected deployment tool CloudFormation is AWS native tool 
that provides the highest compatibility with AWS API.

##### Deployment consist of two parts:        
- Part 1: Create an ECS Registry for application, build Docker image and upload it to the registry.
- Part 2: Deploy docker application on ECS Cluster.
    
###### Steps:
1. Create ECS Repository.
2. Build docker image locally.          
3. Upload created image to ECS Repository.          
4. Create ESC Container stack using CloudFormation           
5. Retrieve URL (using script or via AWS Console)           
  
###### Deployment ways: 
- You can either AWS Console and template files ECS_Repository.json and ECS_EC2_Cluster.json
from infrastructure/aws/cloudformation/template directory to create stacks manually

- Or create/update configuration file (config.ini). 
Set valid variables for your AWS account: `KeyName, VpcId, LoadBalancerSubnetId, InstanceSubnetId`.  
And use `./install.sh` script to simplify deployment .
See installation steps bellow.
 
## Installation requirements
- Next packages must be installed locally to be able to deploy the application:
    - awscli 
    - git
    - docker (docker.io)
    - jq

- AWSCli needs to be configured:
  Use `aws configure` command.

- Permissions:
    - Make sure the curent useer have permissions to run docker (Is member of 'docker' group).
    - CloudFormation stack require lot of different permissions to create 
      different resources. Use Admin account in order to simplify installation.

# Installation
    Let pretend we want to deploy application using name "simple-sinatra-app1"

## Part 1 - Create an ECS Registry for application, build Docker image and upload it to the registry.

##### Help:
Use `./install.sh -h` for help.

### 1. Create ECS repository for application:
Run `./install.sh -n simple-sinatra-app1 -a create-repo`
        
### 2 Build docker image:
    ./install.sh -n simple-sinatra-app1 -a create-image

### 3 Upload docker image to ECS repository:
    ./install.sh -n simple-sinatra-app1 -a upload-image
    
## Part 2 - Deploy docker application on ECS Cluster.    
### 4 Create ECS Cluster with application:
    ./install.sh -n simple-sinatra-app1 -a create-cluster

### 5 Get application URL (Load balancer URL):
    Run `./install.sh -n simple-sinatra-app1 -a info
    
### Additional:
    # To install another stack using existed image
    ./install.sh -n simple-sinatra-app2 -a create-cluster -i <aws-accunt-id>.dkr.ecr.us-east-1.amazonaws.com/simple-sinatra-app1:latest

# How to uninstall   
### Delete ECS Cluster:
    ./install.sh -n simple-sinatra-app1 -a delete-cluster

### Delete ECS Repository:
    ./install.sh -n simple-sinatra-app1 -a delete-repo
