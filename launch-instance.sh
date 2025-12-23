#!/bin/bash

# Exit on any error
set -e

# Function to set GitHub Actions output
set_output() {
    echo "$1=$2" >> "$GITHUB_OUTPUT"
}

# Function to log info
log_info() {
    echo "::info::$1"
}

# Function to log error and exit
log_error() {
    echo "::error::$1"
    exit 1
}

get_random_slug() {
      # Generate random bytes, encode as base64, remove non-alphanumeric chars, and take 8 characters
      echo $(head -c 16 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 8)
}

# Check required inputs
[[ -z "$INPUT_AMI_ID" ]] && log_error "ami-id is required"
[[ -z "$INPUT_SUBNET_ID" ]] && log_error "subnet-id is required"
[[ -z "$INPUT_SECURITY_GROUP_ID" ]] && log_error "security-group-id is required"
[[ -z "$INPUT_TAG_NAME" ]] && log_error "tag-name is required"
[[ -z "$INPUT_TAG_VALUE" ]] && log_error "tag-value is required"
if [ -z "$INPUT_GITHUB_RUNNER_REGISTRATION_TOKEN" ]; then
    if [ -z "$INPUT_RUNNER_NAME" ] || [ -z "$INPUT_RUNNER_LABEL" ]; then
        echo "Error: When github-runner-registration-token is not provided, both runner-name and runner-label must be specified"
        exit 1
    fi
fi

RUNNER_NAME=${INPUT_RUNNER_NAME:-"github-runner-$(get_random_slug)"}
RUNNER_LABEL=${INPUT_RUNNER_LABEL:-"$(get_random_slug)"}

DEFAULT_REGISTER_STARTUP_COMMANDS="#!/bin/bash

cd /home/ubuntu/actions-runner/
export RUNNER_ALLOW_RUNASROOT=1

./config.sh \\
  --url \"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}\" \\
  --token \"${INPUT_GITHUB_RUNNER_REGISTRATION_TOKEN}\" \\
  --labels \"${RUNNER_LABEL}\" \\
  --name \"${RUNNER_NAME}\" \\
  --ephemeral

./run.sh"

DEFAULT_RUN_STARTUP_COMMANDS="#!/bin/bash

cd /home/ubuntu/actions-runner/
export RUNNER_ALLOW_RUNASROOT=1

./run.sh"

if [ -n "$INPUT_STARTUP_COMMANDS" ]; then
    STARTUP_COMMANDS="$INPUT_STARTUP_COMMANDS"
elif [ -n "$INPUT_GITHUB_RUNNER_REGISTRATION_TOKEN" ]; then
    STARTUP_COMMANDS="$DEFAULT_REGISTER_STARTUP_COMMANDS"
else
    STARTUP_COMMANDS="$DEFAULT_RUN_STARTUP_COMMANDS"
fi

# Launch the instance
log_info "Launching EC2 instance from AMI ${INPUT_AMI_ID}"
INSTANCE_INFO=$(aws ec2 run-instances \
    --image-id "$INPUT_AMI_ID" \
    --instance-type "$INPUT_INSTANCE_TYPE" \
    --subnet-id "$INPUT_SUBNET_ID" \
    --security-group-ids "$INPUT_SECURITY_GROUP_ID" \
    ${INPUT_KEY_NAME:+--key-name "$INPUT_KEY_NAME"} \
    --associate-public-ip-address \
    --tag-specifications \
            "ResourceType=instance,Tags=[{Key=Name,Value=${RUNNER_NAME}},{Key=${INPUT_TAG_NAME},Value=${INPUT_TAG_VALUE}}]" \
            "ResourceType=network-interface,Tags=[{Key=${INPUT_TAG_NAME},Value=${INPUT_TAG_VALUE}}]" \
            "ResourceType=volume,Tags=[{Key=${INPUT_TAG_NAME},Value=${INPUT_TAG_VALUE}}]" \
    ${STARTUP_COMMANDS:+--user-data "$STARTUP_COMMANDS"} \
    ${INPUT_IAM_INSTANCE_PROFILE:+--iam-instance-profile "Name=$INPUT_IAM_INSTANCE_PROFILE"} \
    --output json)

# Get the instance ID
INSTANCE_ID=$(echo "$INSTANCE_INFO" | jq -r '.Instances[0].InstanceId')
log_info "Created instance: ${INSTANCE_ID}"

# Wait for instance to be ready if specified
if [[ "$INPUT_WAIT_FOR_READY" != "false" ]]; then
    log_info "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    log_info "Waiting for status checks..."
    aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
fi

log_info "Instance is ready"

# Get latest instance information
INSTANCE_INFO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json)
INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.Reservations[0].Instances[0].State.Name')

set_output "runner-label" "$RUNNER_LABEL"
set_output "instance-id" "$INSTANCE_ID"
set_output "instance-state" "$INSTANCE_STATE"
