#!/bin/bash

set -euxo pipefail

# Check for input argument
if [ -z "$1" ]; then
  echo "Usage: $0 <project-name>"
  echo "Example: $0 my-docker-build"
  exit 1
fi  

PROJECT_NAME=$1
PROJECT_NAME_SANITIZED=$(echo "$PROJECT_NAME" | tr -cd '[:alnum:]')
PROJECT_NAME_LOWER=$(echo "$PROJECT_NAME_SANITIZED" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
API_GROUP="modules.platform.ottawacloudconsulting.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

### Initialize the project
echo -e "${GREEN}🔧 Initializing ..."
up project init $PROJECT_NAME_LOWER && cd $PROJECT_NAME_LOWER

### Add dependencies
echo -e "${BLUE}📦 Adding dependencies ..."
up dependency add xpkg.upbound.io/upbound/provider-aws-iam:>=v1
up dependency add xpkg.upbound.io/upbound/provider-aws-ecr:>=v1
up dependency add xpkg.upbound.io/upbound/provider-aws-s3:>=v1
up dependency add xpkg.upbound.io/upbound/provider-kubernetes:>=v0
up dependency add xpkg.upbound.io/upbound/function-auto-ready:>=v0

### Create XRD
echo -e "${GREEN}🔧 Creating XRD base ..."
up example generate \
    --type="xr" \
    --api-group=$API_GROUP \
    --api-version=v1alpha1 \
    --kind=$PROJECT_NAME_SANITIZED \
    --name=example-project

# # create file contents examples/x$PROJECT_NAME/my-api-container-image.yaml using cat and EOF heredoc
# echo -e "${GREEN}🔧 Populating XRD ..."
# cat <<EOF > examples/$PROJECT_NAME_LOWER/example-project.yaml
# apiVersion: $API_GROUP/v1alpha1
# kind: $PROJECT_NAME_SANITIZED
# metadata:
#   name: example-project
#   labels:
#     platform.ottawacloudconsulting.com/environment: dev
# spec:
#   parameters:
#     ########################
#     # Base Variables
#     ########################
#     region: ca-central-1
#     accountId: "111111111111"
#     providerConfigRef:
#       aws: my-aws-provider
#       kubernetes: my-kubernetes-provider
#     aws_tags:
#       project: "container-pipeline-project"
#       classification: "unclassified"
#       owner: "firstname.lastname@example.com"
#     ########################
#     # ECR Variables
#     ########################
#     ecr_config:
#       repositoryName: my-api-container
#       policyText: |
#         {
#           "Version": "2008-10-17",
#           "Statement": [
#             {
#               "Sid": "RepositoryPolicy",
#               "Effect": "Allow",
#               "Principal": "*",
#               "Action": [
#                 "ecr:BatchCheckLayerAvailability",
#                 "ecr:BatchGetImage",
#                 "ecr:CompleteLayerUpload",
#                 "ecr:DescribeImageScanFindings",
#                 "ecr:GetAuthorizationToken",
#                 "ecr:InitiateLayerUpload",
#                 "ecr:PutImage",
#                 "ecr:StartImageScan",
#                 "ecr:UploadLayerPart"
#               ]
#             }
#           ]
#         }
#     ########################
#     # Workflow Variables
#     ########################
#     workflow_config:
#       repository_type: "ado"
#       repository_url: "dev.azure.com/my-org/my-project/_git/my-repo"
#       branch: "main"
#       dockerfile_directory: ""
#       artifact_bucket: my-artifact-bucket
#       git_readonly_token: "my-git-readonly-token"
#       test_image: "python:3.11-slim"
# EOF

echo -e "${BLUE}📦 Creating XRD Definition"
up xrd generate examples/$PROJECT_NAME_LOWER/example-project.yaml
echo -e "${BLUE}📦 Creating Composition"
up composition generate examples/$PROJECT_NAME_LOWER/example-project.yaml

### Generate the kcl function
echo -e "${BLUE}📦 Generating KCL function ..."
up function generate $PROJECT_NAME_LOWER apis/"$PROJECT_NAME_LOWER"s/composition.yaml
