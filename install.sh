#!/usr/bin/env bash
#
# This script is used to install app from
#   git@github.com:rea-cruitment/simple-sinatra-app.git
#
# Usage:
##  See : ./install.sh -h

set +x
set -o errexit
set -o pipefail
set -o nounset

# Default settings
APP_URL_DEFAULT='http://github.com/rea-cruitment/simple-sinatra-app.git'
CLUSTER_CONFIG_FILE_DEFAULT='config.ini'

####################################################################
ECS_EC2_CLUSTER_TEMPLATE='./infrastructure/aws/cloudformation/template/ECS_EC2_Cluster.json'
ECS_REPOSITORY_TEMPLATE='./infrastructure/aws/cloudformation/template/ECS_Repository.json'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function create_ecs_repository(){
    #
    # create ECS repository for application
    #
    echo "Creating stack ${APP_NAME}-ecs-repository ..."
    aws cloudformation $1-stack \
        --stack-name "${APP_NAME}-ecs-repository" \
        --template-body "file://${DIR}/${ECS_REPOSITORY_TEMPLATE}" \
        --parameters ParameterKey=RepositoryName,ParameterValue="${APP_NAME}"
}


function delete_ecs_repository(){
    #
    # Delete ECS repository
    #

    echo "Deleting images from repository ..."
    # Delete all images from repo first
    IMAGE_DIGESTS=$(aws ecr list-images --repository-name "${APP_NAME}" \
        | jq '.imageIds[].imageDigest' \
        | awk -F '"' '{print $2}')
    for digest in ${IMAGE_DIGESTS} ; do
        echo "Deleting   ${digest}..."
        aws ecr batch-delete-image --repository-name "${APP_NAME}" --image-ids imageDigest="${digest}" | grep 'failures'
    done

    echo "Deleting stack ${APP_NAME}-ecs-repository ..."
    aws cloudformation delete-stack \
        --stack-name "${APP_NAME}-ecs-repository"
}

function get_esc_repository_uri(){
    #
    # Return repository URI by application name
    #
    aws ecr describe-repositories --repository-names "${APP_NAME}" \
        | grep 'repositoryUri' \
        | awk -F '"' '{print $4}'
}

function create_docker_container_image(){
    #
    # Download Application and build docker image
    #
    CURRENT_DIR=$(pwd)
    WORK_DIR=$(mktemp -d)
    echo "WORK_DIR = ${WORK_DIR}"

    cd "${WORK_DIR}"
    git clone "${APP_URL}" "${APP_NAME}"

    # Create docker file
    cat << EOF2 > Dockerfile
FROM ubuntu:16.04
#FROM ruby:2.3.3
# Considered to inherit from ubuntu because ruby:x.x.x may contain older packages installed.
# So the image diff would be bigger.

# Install security updates and bundler package in one line to minimize size of image.
RUN apt-get update -qq \
  && apt-get -s dist-upgrade \
      | grep "^Inst" \
      | grep -i securi \
      | awk -F " " {'print \$2'} \
      | xargs apt-get install \
  && apt-get install -y --no-install-recommends bundler

WORKDIR "/${APP_NAME}"
COPY "/${APP_NAME}" "/${APP_NAME}"
RUN bundle install
CMD bundle exec rackup --host 0.0.0.0
EOF2


    # Build container image
    docker build -t "${APP_NAME}" .

    # Cleanup
    cd "${CURRENT_DIR}"
    rm -fr "${WORK_DIR}"
}

function upload_docker_container_image(){
    #
    # Upload docker image to ECS repository
    #

    # Login to repository
    LOGIN_CMD=$(aws ecr get-login)
    eval "${LOGIN_CMD}"

    # Tag and upload image.
    docker tag "${APP_NAME}:latest" "${DOCKER_IMAGE_URL}"
    docker push "${DOCKER_IMAGE_URL}"
}

function create_ecs_cluster(){
    #
    # Create/update ECS cluster stack
    #
    echo "Creating stack ${APP_NAME}-ecs-cluster ..."
    aws cloudformation "$1-stack" \
        --capabilities CAPABILITY_IAM \
        --stack-name "${APP_NAME}-ecs-cluster" \
        --template-body "file://${DIR}/${ECS_EC2_CLUSTER_TEMPLATE}" \
        --parameters \
            ${CLUSTER_PARAMETERS} \
            ParameterKey=AppName,ParameterValue="${APP_NAME}" \
            ParameterKey=AppDockerImage,ParameterValue="${DOCKER_IMAGE_URL}"
    echo "Go to: https://console.aws.amazon.com/cloudformation/home?#/stacks?filter=active to check progress."

}

function validate_ecs_cluster_template(){
    #
    # Validate CF template
    #
    aws cloudformation validate-template \
        --template-body "file://${DIR}/${ECS_EC2_CLUSTER_TEMPLATE}"
}

function delete_ecs_cluster(){
    #
    # Delete ECS cluster stack
    #
    echo "Deleting stack ${APP_NAME}-ecs-cluster ..."
    aws cloudformation delete-stack \
        --stack-name "${APP_NAME}-ecs-cluster"
}

function read_parameters_from_file(){
    #
    # Read parameter from file and convert them to awscli acceptable format
    # From:
    #    key1=value1
    #    key2=value2
    # To: "ParameterKey=key1,ParameterValue=value1 ParameterKey=key2,ParameterValue=value2"
    #
    cat "$1" \
        | egrep -v '^\s*#|^\s*;|^\s*$'  `# Remove coments and empty lines` \
        | sed 's/^\s*//'                `# Remove empty spaces at the beggin` \
        | sed 's/\s*$//'                `# Remove empty spaces at the end` \
        | sed 's/\s*=\s*/==/'           `# Remove empty spaces around '=' and double it to avoid replacement conflicts` \
        | sed 's/^/ParameterKey=/'      `# Mark Key` \
        | sed 's/==/,ParameterValue=/'  `# Mark Value` \
        | sed 's/\r//g'                 `# Remove "return char"` \
        | paste -sd " " -               `# Join parameters`
}

function confirm_operation(){
    read -r -p "Are you sure? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function show_help(){
    cat << EOH
Usage:
  $0 -n <name> -a <action> [-f config.ini] [-u git-url ] [-i docker-image-url]

  Name:             Application name.
  Actions:
    create-repo:    Create Docker repository for application.
    create-image:   Build Docker image from sources.
    upload-image:   Upload to ECS Repository.
    create-cluster: Create ESC cluster stack with application.
                        Configuration file required for this step. (Default: ${CLUSTER_CONFIG_FILE_DEFAULT})
                        File format (Each parameter in separate line):
                            KeyName=my_rsa_key
                            VpcId=vpc-4e219637
                            ...
    update-cluster: Update application cluster stack.
    delete-cluster: Delete application cluster stack.
    delete-repo:    Delete Docker repository for application.
    info:           Get information about app installation.

  git-url:          The Git URL with sources (Default: ${APP_URL_DEFAULT})
  docker-image-url: Docker image URL (Example: <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/app-name:last )

EOH
}


function show_info(){

    ALB_ARN=$(aws cloudformation describe-stack-resources \
        --stack-name "${APP_NAME}-ecs-cluster"  \
        --logical-resource-id  EscApplicationLoadBalancer \
            | jq '.StackResources[0].PhysicalResourceId' \
            | tr -d '"'  )

    ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "${ALB_ARN}" \
            | jq '.LoadBalancers[0].DNSName'\
            | tr -d '"')
    echo "Application URL: http://${ALB_DNS_NAME}"

}

###################################################################################################

APP_URL=${APP_URL_DEFAULT}
CLUSTER_CONFIG_FILE=${CLUSTER_CONFIG_FILE_DEFAULT}
DOCKER_IMAGE_URL='NotSet'

while getopts ":a:n:hf:u:i:" opt; do
  case "${opt}" in
    h)
        show_help
        exit 0
        ;;
    a)
        ACTION="${OPTARG}"
        ;;
    n)
        APP_NAME="${OPTARG}"
        ;;
    u)
        APP_URL="${OPTARG}"
        ;;
    f)
        CLUSTER_CONFIG_FILE="${OPTARG}"
        ;;
    i)
        DOCKER_IMAGE_URL="${OPTARG}"
        ;;
    \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
  esac
done

CLUSTER_PARAMETERS=$(read_parameters_from_file "${CLUSTER_CONFIG_FILE}")

# Detect image by App name if not set explicitly.
case "${ACTION}" in
    upload-image|create-cluster|update-cluster)
        if [ "${DOCKER_IMAGE_URL}" == "NotSet" ]; then
            REPO_URL=$(get_esc_repository_uri)
            DOCKER_IMAGE_URL="${REPO_URL}:latest"
        fi
        ;;
esac


case "${ACTION}" in
    create-repo)
        create_ecs_repository create
        ;;
    update-repo)
        create_ecs_repository update
        ;;
    delete-repo)
        confirm_operation
        delete_ecs_repository
        ;;
    create-image)
        create_docker_container_image
        ;;
    upload-image)
        upload_docker_container_image
        ;;
    create-cluster)
        create_ecs_cluster create
        ;;
    update-cluster)
        create_ecs_cluster update
        ;;
    delete-cluster)
        confirm_operation
        delete_ecs_cluster
        ;;
    validate)
        validate_ecs_cluster_template
        ;;
    info)
        show_info
        ;;
    *)
        echo "Invalid action: ${ACTION}" >&2
        exit 1
        ;;
esac
