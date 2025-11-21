# This script prepares an Ubuntu instance before it is saved as an AMI. The instance created from it must be configured on-the-fly.

sudo apt-get update

mkdir actions-runner && cd actions-runner
case $(uname -m) in aarch64) ARCH="arm64" ;; amd64|x86_64) ARCH="x64" ;; esac && export RUNNER_ARCH=${ARCH}
curl -o actions-runner-linux-${RUNNER_ARCH}-2.328.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-linux-${RUNNER_ARCH}-2.328.0.tar.gz
tar xzf ./actions-runner-linux-${RUNNER_ARCH}-2.328.0.tar.gz

# Create the runner
./config.sh --url https://github.com/owner/repo --token ABCDEFabcdef --labels \"${RUNNER_LABEL}\" --name \"${RUNNER_NAME}\" \\
