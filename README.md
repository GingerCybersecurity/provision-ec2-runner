# Provision EC2 Runner
Launch EC2 instance from AMI for GitHub self-hosted runner

This action works in conjunction with [terminate-ec2-runner](https://github.com/gingercybersecurity/terminate-ec2-runner) for complete lifecycle management.

## Getting started

### 1. GitHub Authentication
You need a GitHub token with appropriate permissions. Choose one of these options:

#### Option A: GitHub App (Recommended for Organizations)
- Best for organization-wide access and long-term integrations
- Required Permission: "Self-hosted runners" (write)
- Use [create-github-app-token](https://github.com/actions/create-github-app-token) to generate temporary tokens
- [Learn more about GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps)

#### Option B: Personal Access Token
- Suitable for individual repositories
- Required Scopes:
    - `admin:org` for general access
    - `repo` for private repositories
- Store securely using GitHub Secrets
- [Token management guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

### 2. AWS IAM Configuration

At minimum, this action will need permission to create and list EC2 instances and create tags.

```
ec2:RunInstances
ec2:TerminateInstances
ec2:DescribeInstances
ec2:DescribeInstanceStatus
ec2:CreateTags
```

You will need additional permissions if attaching an IAM role to the instance:

```
ec2:ReplaceIamInstanceProfileAssociation
ec2:AssociateIamInstanceProfile
iam:PassRole
```

Security Best Practices:
- Implement tag-based access control
- Use [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) for AWS authentication
- See `examples/example-workflow.yml` for implementation

### 3. EC2 Image Setup

Create a custom AMI with:
- Required job software
- GitHub runner software
- Ubuntu operating system (default)

Creation Options:
- [Manual AMI creation](https://docs.aws.amazon.com/toolkit-for-visual-studio/latest/user-guide/tkv-create-ami-from-instance.html)
- Automated tools:
    - [Packer](https://www.packer.io/)
    - [EC2 Image Builder](https://aws.amazon.com/image-builder/)

Reference `examples/prep-ubuntu-runner.sh` for Ubuntu runner setup commands.

### 4. Network Security

Security Group Requirements:
- Outbound: HTTPS (port 443) only
- Inbound: No access required
- Dedicated security group recommended

## Implementation

1. Review example workflows in `./examples`
2. Configure inputs as specified in `action.yml`
3. Add [terminate-ec2-runner](https://github.com/gingercybersecurity/terminate-ec2-runner) to clean up resources
4. Consider [self-hosted runner security guidelines](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#self-hosted-runner-security)

Notes:
- Runners are configured as ephemeral by default
- Custom startup commands available via `startup-commands` parameter
- Recommended for private repositories only
- Default configuration in `launch-instance.sh`
