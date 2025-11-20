# AWS Q Developer CLI

AI-powered assistance for AWS and command-line tasks directly in your terminal.

## Overview

Amazon Q Developer for command line provides AI assistance for AWS CLI commands, code generation, and general
development tasks.  Powered by Anthropic's Claude 3.7 Sonnet (as of March 2025), it offers enhanced conversational
capabilities and agentic coding features.

**Key Features:**

- **Natural Language to AWS CLI**: Generate AWS commands from descriptions
- **Command Explanations**: Understand complex AWS CLI syntax
- **Code Generation**: Create AWS-specific code (Lambda, CDK, etc.)
- **Agentic Coding**: Read/write files, test code, debug iteratively
- **AWS Resource Queries**: Query AWS resources directly from CLI
- **Inline Suggestions**: Command autocompletion for 100+ CLIs
- **Free & Pro Tiers**: Builder ID (free) or IAM Identity Center (Pro)

## Prerequisites

- **AWS CLI**: Must be installed (via cloud-tools extension)
- **Authentication**: AWS Builder ID (free) or IAM Identity Center (Pro)

## Installation

AWS Q Developer is built into the AWS CLI (version 2.x):

```bash
# Verify AWS CLI version
aws --version

# Should be 2.x or higher
```

## Authentication

### Free Tier (AWS Builder ID)

```bash
# Login with Builder ID
q login
# Or
q login --license free

# Follow browser authentication
```

### Pro Tier (IAM Identity Center)

```bash
# Login with IAM Identity Center
q login --license pro \
  --identity-provider https://my-company.awsapps.com/start \
  --region us-east-1

# Follow SSO authentication
```

## Basic Commands

### Chat

Interactive AI conversation:

```bash
# Start chat
q chat
# Or just: q

# With initial message
q chat "How do I create an S3 bucket?"

# Resume previous conversation
q chat --resume
```

### Translate

Convert natural language to shell commands:

```bash
# Get command suggestions
q translate "list all EC2 instances"
q translate "find all Python files modified in last week"
q translate "create a Lambda function"

# Execute suggestion directly (review first!)
$(q translate "stop all running EC2 instances")
```

### Inline Suggestions

Enable/disable command autocompletion:

```bash
# Enable inline suggestions
q inline enable

# Disable
q inline disable

# Check status
q inline status
```

## AWS-Specific Use Cases

### EC2 Management

```bash
q chat
> List all running EC2 instances in us-east-1
> Stop instance i-abc123
> Create a new t2.micro instance with Amazon Linux 2
```

### S3 Operations

```bash
q chat
> Create an S3 bucket with versioning enabled
> Upload all files in ./dist to s3://my-bucket
> Set bucket policy for public read access
```

### Lambda Functions

```bash
q chat
> Create a Lambda function that processes S3 events
> Write Python code for image resizing Lambda
> Deploy Lambda with SAM template
```

### CloudFormation/CDK

```bash
q chat
> Generate CloudFormation template for VPC with subnets
> Create CDK stack for serverless API
> Explain this CloudFormation template
```

### IAM & Security

```bash
q chat
> Create IAM role for Lambda with S3 access
> Generate least-privilege policy for EC2
> Audit IAM policies for security issues
```

## Enhanced CLI Agent (March 2025)

### Agentic Capabilities

Amazon Q can now:

- Read and write files locally
- Test code and iterate
- Debug issues with feedback loop
- Query AWS resources
- Create and modify infrastructure

```bash
q chat
> Create a serverless API with API Gateway and Lambda
# Q Developer will:
# 1. Design architecture
# 2. Write Lambda code
# 3. Create SAM/CDK template
# 4. Test locally
# 5. Deploy to AWS
# 6. Verify deployment
```

### Iterative Development

```bash
q chat
> Create a user authentication API

# After initial code
> Add password hashing with bcrypt
> Include JWT token generation
> Write unit tests
> Add input validation

# Q iteratively improves based on your feedback
```

### File Operations

```bash
q chat
> Read the current Lambda function code
> Modify it to add error handling
> Write the updated code to lambda-function.py
```

## Common Workflows

### Infrastructure Setup

```bash
q chat
> Set up a production VPC with public and private subnets
> Create an RDS PostgreSQL database
> Configure security groups
> Generate Terraform files for this infrastructure
```

### Deployment

```bash
q chat
> Deploy my Express app to Elastic Beanstalk
> Create a CodePipeline for CI/CD
> Set up blue-green deployment
```

### Monitoring

```bash
q chat
> Show CloudWatch logs for my Lambda function
> Create CloudWatch alarms for API errors
> Query metrics for the last hour
```

### Cost Optimization

```bash
q chat
> Analyze my EC2 instances for right-sizing opportunities
> Find unused EBS volumes
> Suggest cost optimization for this architecture
```

## Slash Commands

### /model

Select AI model:

```bash
q chat
> /model

# Options:
# - GPT-5.1 (highest quality)
# - GPT-5.1-Codex (code-optimized)
# - Gemini 3 Pro (Google's latest)
# - Claude 3.7 Sonnet (reasoning)
```

### /share

Save conversation:

```bash
q chat
> /share

# Save as:
# - Markdown file locally
# - Public GitHub gist
# - Private GitHub gist
```

### /usage

View usage statistics:

```bash
q chat
> /usage

# Shows:
# - Premium requests used
# - Session duration
# - Lines of code edited
# - API calls made
```

### /delegate

Hand off to coding agent:

```bash
q chat
> /delegate

# Creates feature branch
# Commits current work
# Launches coding agent for implementation
```

## Configuration

### MCP Servers

Extend Q with Model Context Protocol:

```bash
# Add MCP server
q mcp add server-name --config server-config.json

# List servers
q mcp list

# Remove server
q mcp remove server-name
```

### Preferences

```bash
# Configure preferences
q config set

# Options:
# - Default model
# - Stream responses
# - Save history
# - Inline suggestions
```

## Best Practices

### 1. Use for AWS Tasks

```bash
# Leverage AWS expertise
q chat "Best practices for Lambda cold start optimization"
q chat "Design multi-region failover for RDS"
```

### 2. Command Discovery

```bash
# Learn new CLI tools
q translate "list all ECS services"
q explain "aws ec2 describe-instances --filters ..."
```

### 3. Code Generation

```bash
# Generate AWS SDK code
q chat "Write Python boto3 code to upload file to S3"
q chat "Create Lambda function for SNS message processing"
```

### 4. Verify Commands

```bash
# Get suggestion
q translate "delete all unattached EBS volumes"

# IMPORTANT: Review before executing!
# Understand what it does
# Verify it matches your intent
# Then execute manually
```

## Inline Suggestions

When enabled, Q provides autocompletions:

```bash
# Enable
q inline enable

# Now type partial commands:
aws s3 ls <Tab>
# Q suggests: --bucket my-bucket --recursive

docker run <Tab>
# Q suggests: -d -p 3000:3000 my-image
```

## Diagnostic Tools

```bash
# Run diagnostics
q doctor

# Checks:
# - AWS CLI installation
# - Authentication status
# - Q CLI version
# - Network connectivity
# - Permissions
```

## Troubleshooting

### Not Authenticated

```bash
# Login with Builder ID (free)
q login

# Or Pro tier
q login --license pro
```

### AWS CLI Not Found

```bash
# Install AWS CLI via cloud-tools extension
extension-manager install cloud-tools

# Verify installation
aws --version
```

### Inline Not Working

```bash
# Check status
q inline status

# Re-enable
q inline disable
q inline enable

# Restart shell
exec bash
```

### Rate Limiting

- **Free tier**: Limited requests per month
- **Pro tier**: Higher limits
- **Solution**: Upgrade to Pro or wait for quota reset

## Additional Resources

### Official Links

- **Documentation**: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line.html
- **CLI Reference**: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-reference.html
- **Learning Center**: https://aws.amazon.com/developer/learning/q-developer-cli/
- **GitHub**: https://github.com/aws/amazon-q-developer-cli

### Blog Posts

- **CLI Agent Launch**: https://aws.amazon.com/blogs/devops/introducing-the-enhanced-command-line-interface-in-amazon-q-developer/
- **Natural Language AWS**: https://aws.amazon.com/blogs/devops/effortlessly-execute-aws-cli-commands-using-natural-language-with-amazon-q-developer/
- **Latest Features**: https://aws.amazon.com/blogs/devops/exploring-the-latest-features-of-the-amazon-q-developer-cli/

### Support

- AWS Support
- AWS re:Post: https://repost.aws
- Community forums

## Version History

- **March 2025**: Enhanced CLI agent with Claude 3.7 Sonnet, agentic coding
- **2024**: Initial Q Developer CLI launch
- Continuous updates with new models and features

## License

Included with AWS CLI - See AWS terms of service
