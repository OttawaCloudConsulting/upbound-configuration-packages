schema OXR:
    """
    Composite resource schema for ContainerWorkflow, used in the group `modules.platform.ottawacloudconsulting.com/v1alpha1`.

    Attributes
    ----------
    apiVersion: str, required.
        The API version of the composite resource.
    kind: str, required.
        The kind of composite resource.
    metadata: object, required.
        Kubernetes resource metadata such as name, labels, and annotations.
    spec: OXRSpec, required.
        The specification block containing desired parameters.
    """

    apiVersion: str = "modules.platform.ottawacloudconsulting.com/v1alpha1"
    kind: str = "ContainerWorkflow"
    metadata: OXRMetadata
    spec: OXRSpec

schema OXRMetadata:
    """
    The `metadata` field defines standard Kubernetes resource metadata for the composite resource. This metadata is useful for identification, scoping, labeling, and integration with Crossplane, ArgoCD, and other Kubernetes-native tooling.
    
    Attributes
    ----------
    name: str, required.
        The name of the composite resource, which is used to identify it within the Kubernetes cluster.
    annotations: {str: str}, optional.
        Annotations are key-value pairs that can be used to store additional information about the resource, such as metadata for tools like ArgoCD or Crossplane.
    labels: {str: str}, optional.
        Labels are key-value pairs that can be used to categorize and organize resources within Kubernetes, enabling filtering and selection based on specific criteria.
    str: any, optional.
        This allows for additional custom metadata fields to be added to the composite resource, enabling extensibility and flexibility in defining the resource's configuration.
    """
    name: str
    annotations?: {str: str}
    labels?: {str: str}
    [str]: any

schema OXRSpec:
    """
    The top-level specification for the ContainerWorkflow composite resource.

    Attributes
    ----------
    parameters: OXRSpecParameters, required.
        Parameters supplied by the user to configure the composition.
    """
    parameters: OXRSpecParameters
    [str]: any


schema OXRSpecParameters:
    """
    Parameters that control the behavior and configuration of the container pipeline module.

    Attributes
    ----------
    accountId: str, required.
        The AWS account ID under which the pipeline resources will be created.
    region: str, required.
        The AWS region in which to deploy the resources.
    aws_tags: AwsTags, optional.
        A collection of standard AWS tagging metadata used across all resources.
    ecr_config: EcrConfig, optional.
        Configuration settings for the ECR repository and its policy.
    workflow_config: WorkflowConfig, optional.
        Settings for the container build workflow (e.g., Git repo, branch, Dockerfile path).
    providerConfigRef: ProviderConfigRef, optional.
        References to external Crossplane provider configs (AWS, Kubernetes).
    """
    accountId: str
    region: str
    aws_tags?: AwsTags
    ecr_config?: EcrConfig
    workflow_config?: WorkflowConfig
    providerConfigRef?: ProviderConfigRef
    [str]: any


schema AwsTags:
    """
    Common AWS tagging structure applied to all provisioned resources.

    Attributes
    ----------
    classification: str, optional.
        The classification tag (e.g., "internal", "external", "confidential").
    owner: str, optional.
        Identifies the owner or responsible team.
    project: str, optional.
        The name of the project associated with the resources.
    """
    classification?: str
    owner?: str
    project?: str
    [str]: any


schema EcrConfig:
    """
    Configuration for the Amazon Elastic Container Registry (ECR).

    Attributes
    ----------
    repositoryName: str, required.
        The name of the ECR repository to be created or managed.
    policyText: str, required.
        JSON-formatted IAM policy text that governs access to the repository.
    """
    repositoryName: str
    policyText: str
    [str]: any


schema WorkflowConfig:
    """
    Configuration for the container build and deployment workflow.

    Attributes
    ----------
    artifact_bucket: str, optional.
        Name of the S3 bucket where build artifacts should be stored.
    branch: str, optional.
        Git branch to monitor or use as source during build.
    dockerfile_directory: str, optional.
        Directory path where the Dockerfile is located within the repo.
    git_readonly_token: str, optional.
        GitHub or GitLab token used for read-only access to the repo.
    repository_type: str, optional.
        The type of VCS provider (e.g., "github", "gitlab").
    repository_url: str, optional.
        The HTTPS or SSH URL of the source code repository.
    test_image: str, optional.
        A container image used for test or validation purposes.
    """
    artifact_bucket?: str
    branch?: str
    dockerfile_directory?: str
    git_readonly_token?: str
    repository_type?: str
    repository_url?: str
    test_image?: str
    [str]: any


schema ProviderConfigRef:
    """
    References to the Crossplane provider configurations (e.g., AWS, Kubernetes).

    Attributes
    ----------
    name: str, required.
        The name of the referenced providerConfig object.
    kubernetes: str, optional.
        Optional Kubernetes provider reference, for cases involving both AWS and Kubernetes.
    """
    aws: str
    kubernetes?: str
    [str]: any