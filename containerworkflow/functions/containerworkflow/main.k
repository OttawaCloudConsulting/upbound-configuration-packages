### IMPORTS
# ==============================================================================

import .schema  as schema

import models.io.upbound.aws.ecr.v1beta1 as ecrv1beta1
import models.io.upbound.aws.ecr.v1beta2 as ecrv1beta2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1

# import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
# import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
# import models.io.upbound.aws.s3.v1beta1 as s3v1beta1
# import models.io.upbound.aws.s3.v1beta2 as s3v1beta2
# import models.io.upbound.aws.v1alpha1 as awsv1alpha1
# import models.io.upbound.aws.v1beta1 as awsv1beta1
# import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# Naming conventions and utility functions
# ==============================================================================
import .naming

namingParams = naming.NamingParams{ ## Move to XR
    environment: "dev"
    system: "crossplane"
    serviceLine: "platform"
}

# FUNCTIONS
# ==============================================================================

isResourceReady = lambda name: str -> bool {
    _resource = option("params")?.ocds?[name]?.Resource
    _conditions = _resource?.status?.conditions or []
    _readyCondition = [x for x in _conditions if x.type == "Ready"]?[0]
    _readyCondition?.status == "True" or False
}

areResourcesReady = lambda names: [str] -> bool {
    all_true([isResourceReady(x) for x in names])
}

findById = lambda data: any, id: str, key: str = "id" -> any {
    [x for x in data if x[key] == id]?[0]
}
# ==============================================================================


# COMPOSITION
# ==============================================================================

# Load parameters
oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

xr: schema.OXR = option("params").oxr
params = xr.spec.parameters

# # Load parameters
# xr = schema.OXR{ **option("params").oxr}
# ocds = option("params").ocds
# params = xr.spec.parameters

_repo = params.ecr_config.repositoryName
_region = params.region
_tags = params.aws_tags or {}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

### TODO: Move variables to XR parameters
_federatedPrincipal =  "arn:aws:iam::111111111111:oidc-provider/oidc.eks.ca-central-1.amazonaws.com/id/123a456b789c123d456e789f123a456b"
_oidcProvider = "oidc.eks.ca-central-1.amazonaws.com/id/123a456b789c123d456e789f123a456b"



_accountId = params.accountId or "111111111111"

_items = [
    ecrv1beta2.Repository{ # ECR Repository
        metadata: {
            name: naming.resource_name(namingParams, params.ecr_config.repositoryName)
            annotations: _metadata(naming.resource_name(namingParams, params.ecr_config.repositoryName)).annotations
            labels = {
                "app.kubernetes.io/name" = naming.resource_name(namingParams, params.ecr_config.repositoryName)
                "app.kubernetes.io/part-of" = "${naming.resource_name(namingParams, params.ecr_config.repositoryName)}-repository"
                "app.kubernetes.io/component" = "ecr-repository"
            },
        }
        apiVersion: "ecr.aws.upbound.io/v1beta2"
        kind: "Repository"
        spec: {
            forProvider: {
                region: params.region or "ca-central-1"
                encryptionConfiguration: [
                    {
                        encryptionType: "AES256"
                    }
                ]
                imageScanningConfiguration: {
                    scanOnPush: True  # Image scanning is set to always be enabled on push
                }
            }
            providerConfigRef: {
                name: params.providerConfigRef?.aws or ""
            }
        }
    }
    ecrv1beta1.RepositoryPolicy{ # ECR Repository Policy
        metadata: {
            annotations: _metadata(params.ecr_config.repositoryName + "-policy").annotations
            labels = {
                "app.kubernetes.io/part-of" = "${params.ecr_config.repositoryName}-repository"
                "app.kubernetes.io/component" = "ecr-repository-policy"
            },
        }
        apiVersion: "ecr.aws.upbound.io/v1beta1"
        kind: "RepositoryPolicy"
        spec: {
            forProvider: {
                region:  params.region or "ca-central-1"
                repositorySelector: {
                    matchControllerRef: True
                    matchLabels: {
                        "app.kubernetes.io/component" = "ecr-repository"
                    }
                }
            }
            initProvider: {
                if not isnullish(params.ecr_config.policyText):
                    policy: params.ecr_config.policyText
                else:
                    policy: """
                        {
                            "Version": "2012-10-17",
                            "Statement": [
                            {
                                "Sid": "AllowPull",
                                "Effect": "Allow",
                                "Principal": {
                                "AWS": [
                                    "arn:aws:iam::${_accountId}:root" 
                                ]
                                },
                                "Action": [
                                "ecr:GetDownloadUrlForLayer",
                                "ecr:BatchGetImage",
                                "ecr:BatchCheckLayerAvailability"
                                ]
                            },
                            {
                                "Sid": "AllowPush",
                                "Effect": "Allow",
                                "Principal": {
                                "AWS": [
                                    "arn:aws:iam::${_accountId}:root"
                                ]
                                },
                                "Action": [
                                "ecr:PutImage"
                                ]
                            }
                            ]
                        }
                        """
            }
            providerConfigRef: {
                name: params.providerConfigRef?.aws or ""
            }
        }
    }
    ecrv1beta1.LifecyclePolicy{ # ECR Lifecycle Policy
        metadata: {
            annotations: _metadata(params.ecr_config.repositoryName + "-lifecyclepolicy").annotations
            labels = {
                "app.kubernetes.io/part-of" = "${params.ecr_config.repositoryName}-repository"
                "app.kubernetes.io/component" = "ecr-repository-lifecycle-policy"
            },
        }
        apiVersion: "ecr.aws.upbound.io/v1beta1"
        kind: "LifecyclePolicy"
        spec: {
            forProvider: {
                region: params.region or "ca-central-1"
                repositorySelector: {
                    matchControllerRef: True
                    matchLabels: {
                        "app.kubernetes.io/component" = "ecr-repository"
                    }
                }
                policy: """
                    {
                        "rules": [
                        {
                            "rulePriority": 1,
                            "description": "Expire untagged images older than 30 days",
                            "selection": {
                            "tagStatus": "untagged",
                            "countType": "sinceImagePushed",
                            "countUnit": "days",
                            "countNumber": 30
                            },
                            "action": {
                            "type": "expire"
                            }
                        }
                        ]
                    }
                """
            }
            providerConfigRef: {
                name: params.providerConfigRef?.aws or ""
            }
        }   
    }
    iamv1beta1.Role{ # IAM Role for ECR
        metadata: {
            name: naming.resource_name(namingParams, params.ecr_config.repositoryName + "-iam-role")
            # name: params.ecr_config.repositoryName + "-management-role" # Role specified for IAM requirements
            annotations: _metadata(params.ecr_config.repositoryName + "-iam-role").annotations
            labels = {
                "app.kubernetes.io/part-of" = "${params.ecr_config.repositoryName}-repository"
                "app.kubernetes.io/component" = "iam-role"
            },
        }
        apiVersion: "iam.aws.upbound.io/v1beta1"
        kind: "Role"
        spec: {
            forProvider: {
                assumeRolePolicy: """
                    {
                        "Version": "2012-10-17",
                        "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                            "Federated": ${_federatedPrincipal}
                            },
                            "Action": "sts:AssumeRoleWithWebIdentity",
                            "Condition": {
                            "StringLike": {
                                "${_oidcProvider}:sub": [
                                "system:serviceaccount:*:*build-push-image*"
                                ]
                            }
                            }
                        }
                        ]
                    }
                """
            }
            providerConfigRef: {
                name: params.providerConfigRef?.aws or ""
            }
        }
    }
    iamv1beta1.RolePolicy{ # IAM Management Role Policy
        metadata: {
            annotations: _metadata(params.ecr_config.repositoryName + "-iam-role-policy").annotations
            labels = {
                "app.kubernetes.io/part-of" = "${params.ecr_config.repositoryName}-repository"
                "app.kubernetes.io/component" = "iam-role-policy"
            },
        }
        apiVersion: "iam.aws.upbound.io/v1beta1"
        kind: "RolePolicy"
        spec: {
            forProvider: {
                roleSelector: {
                    matchControllerRef: True
                    matchLabels: {
                        "app.kubernetes.io/component" = "iam-role"
                    }
                }
                policy: """
                    {
                        "Version" : "2012-10-17",
                        "Statement" : [
                        {
                            "Sid": "AllowECRActions",
                            "Effect" : "Allow",
                            "Action" : [
                            "ecr:*"
                            ],
                            "Resource" : "arn:aws:ecr:${params.region}:${params.accountId}:repository/${params.ecr_config.repositoryName}"
                        },
                        {
                            "Sid": "AllowCloudTrail",
                            "Effect" : "Allow",
                            "Action" : [
                            "cloudtrail:LookupEvents"
                            ],
                            "Resource" : "*"
                        },
                        {
                            "Sid": "ECRGetAuthorizationToken",
                            "Effect": "Allow",
                            "Action": [
                            "ecr:GetAuthorizationToken"
                            ],
                            "Resource": "*"
                        },
                        {
                            "Sid": "CreateECRReplicationRole",
                            "Effect" : "Allow",
                            "Action" : [
                            "iam:CreateServiceLinkedRole"
                            ],
                            "Resource" : "*",
                            "Condition" : {
                            "StringEquals" : {
                                "iam:AWSServiceName" : [
                                "replication.ecr.amazonaws.com"
                                ]
                            }
                            }
                        },
                        {
                            "Sid": "AllowS3BucketAccess",
                            "Effect" : "Allow",
                            "Action" : [
                            "s3:*"
                            ],
                            "Resource": [
                            "arn:aws:s3:::${params.workflow_config.artifact_bucket}",
                            "arn:aws:s3:::${params.workflow_config.artifact_bucket}/*"
                            ]
                        }
                        ]
                    }
                """
            }
            providerConfigRef: {
                name: params.providerConfigRef?.aws or ""
            }
        }

    }
]


items = _items
