## REA task 
    
    Idea: 
        Run the application in ECS container using CloudFormation for deployment.
    
    This approach provides a unified scalable way to deploy stateless applications.
    Usage of dockers ensures that the result of deployment would be the same all the time.
    
    Security:
        Access to the port where the application is running on as well as access to SSH port of instances is controlled by AWS Security Groups. 

        Containerized application provides the additional level of security.
        
    Scalability:
        You can easily scale up and down the application based on different triggers ( HTTP-error-500, CPU-load .. etc..)
    
    Availability:
        The application is launched in two or more availability zones.

    Deployment:      
      Selected deployment tool CloudFormation is AWS native tool 
      that provides the highest compatibility with AWS API.

      Deployment consist of two parts:        
         Part 1 - Create an ECS Registry for application, build Docker image and upload it to the registry.
         Part 2 - Deploy docker application on ECS Cluster.
        
        Steps:
            1. Create ECS Repository.
            2. Build docker image locally.          
            3. Upload created image to ECS Repository.          
            4. Create ESC Container stack using CloudFormation           
            5. Retrive URL (using script or via AWS Console)           
      
      Deploymand way: 
          You can either AWS Console and template files ECS_Repository.json and ECS_EC2_Cluster.json  
          from infrastricture/aws/cloudformation/template directory to create stacks manually
           
          or create/update configuration file (config.ini)
          Set valid pvariables for at least: KeyName, VpcId, LoadBalancerSubnetId, InstanceSubnetId.  
          and use ./install.sh script to simplify deployment .
          See installation steps bellow.
 
#### Installation requirements
    Next packages must be installed locally to be able to deploy the application:
        awscli, git, docker, jq
    
    AWS permissions:
        CloudFormation stack require lot of different permissions to create 
        different resources. So is easily to run under Admin account.  

### Installation
    Let pretend we want to deploy application using name "simple-sinatra-app1"

#### Part 1 - Create an ECS Registry for application, build Docker image and upload it to the registry.

##### Use -h for help:
    ./install.sh -h  

##### 1. Create ECS repository for application:
    ./install.sh -n simple-sinatra-app1 -a create-repo
        
##### 2 Build docker image:
    ./install.sh -n simple-sinatra-app1 -a create-image

##### 3 Upload docker image to ECS repository:
    ./install.sh -n simple-sinatra-app1 -a upload-image
    
#### Part 2 - Deploy docker application on ECS Cluster.    
##### 4 Create ECS Cluster with application:
    ./install.sh -n simple-sinatra-app1 -a create-cluster

##### 5 Get application URL (Load balancer URL):
    ./install.sh -n simple-sinatra-app-1 -a info
    
##### Additional:
    # To install another stack using existed image
    ./install.sh -n simple-sinatra-app2 -a create-cluster -i <aws-accunt-id>.dkr.ecr.us-east-1.amazonaws.com/simple-sinatra-app1:latest

### How to uninstall   
##### Delete ECS Cluster:
    ./install.sh -n simple-sinatra-app1 -a delete-cluster

##### Delete ECS Repository:
    ./install.sh -n simple-sinatra-app1 -a delete-repo
