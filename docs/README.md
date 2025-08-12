
Using upbound cli we create a new project using:

```shell
up project init {project-name}
```

This will generate the skeleton structure:

```shell
.
├── apis
├── examples
├── functions
├── LICENSE
└── upbound.yaml
```

The upbound cli allows integration of VS Code with IntelliSense

We must update the upbound.yaml with our project specific information:

```yaml
apiVersion: meta.dev.upbound.io/v1alpha1
kind: Project
metadata:
  name: {project-name}
spec:
  description: This is where you can describe your project.
  license: Apache-2.0
  maintainer: Maintainer Name <user@example.com>
  readme: |
    This is where you can add a readme for your project.
  repository: repository where the configuration package will be pushed
  source: source repository URL
```

First we add our dependencies, which are the UpBound Providers. These will be the relevant providers used in the project. 

Example:

```shell
up dependency add xpkg.upbound.io/upbound/provider-aws-iam:>=v1
up dependency add xpkg.upbound.io/upbound/provider-aws-ecr:>=v1
up dependency add xpkg.upbound.io/upbound/provider-aws-s3:>=v1
up dependency add xpkg.upbound.io/upbound/provider-kubernetes:>=v0
up dependency add xpkg.upbound.io/upbound/function-auto-ready:>=v0
```

These will be added to the upbound.yaml dynamically under the spec.dependsOn section:

```yaml
apiVersion: meta.dev.upbound.io/v1alpha1
kind: Project
metadata:
  name: {project-name}
spec:
  dependsOn:
  - provider: xpkg.upbound.io/upbound/provider-aws-iam
    version: v1.23.1
  - provider: xpkg.upbound.io/upbound/provider-aws-ecr
    version: v1.23.1
  - provider: xpkg.upbound.io/upbound/provider-aws-s3
    version: v1.23.1
  - provider: xpkg.upbound.io/upbound/provider-kubernetes
    version: v0.18.1
  - function: xpkg.upbound.io/upbound/function-auto-ready
    version: v0.5.0
  - function: xpkg.upbound.io/crossplane-contrib/function-auto-ready
    version: '>=v0.0.0'
  description: This is where you can describe your project.
  license: Apache-2.0
  maintainer: Upbound User <user@example.com>
  readme: |
    This is where you can add a readme for your project.
  repository: repository where the configuration package will be pushed
  source: source repository URL
```

Using UpBound CLI we can create a function-first design approach, and create the example XR first.

We create the XR Example skeleton using up cli

```shell
up example generate \
    --type="xr" \
    --api-group=$APIGroupName \
    --api-version=v1alpha1 \
    --kind=$ProjectName \
    --name=example-project
```

This creates the file `examples/{kind-value}/{name}.yaml'

We can then edit the yaml file and create the spec. parameters we expect to use:.

Example:

```yaml
apiVersion: modules.platform.ottawacloudconsulting.com/v1alpha1
kind: ContainerWorkflow
metadata:
  name: example-project
  labels:
    platform.ottawacloudconsulting.com/environment: dev
spec:
  parameters:
    ########################
    # Base Variables
    ########################
    region: ca-central-1
    accountId: "111111111111"
    providerConfigRef:
      aws: my-aws-provider
      kubernetes: my-kubernetes-provider
    aws_tags:
      project: "container-pipeline-project"
      classification: "unclassified"
      owner: "firstname.lastname@example.com"
```

Once we have created our updated example, we then create the XRD using upbound cli:

```shell
up xrd generate examples/$ProjectName/example-project.yaml
```

This creates a full XRD (CompositeResourceDefinition) structure that we can immediately use, with minimal effort.

The XRD is generated as `apis/

Next we move on to the Composition

We can use the upbound cli to generate the composition skeleton to start working with:

```shell
up composition generate apis/{kind-value}/definition.yaml --path apis/{kind-value}/composition.yaml
```

This creates the yaml file apis/{kind-value}/{name}.yaml

Now we create our functions.

```shell
up function generate {function-name} apis/{kind-value}/composition.yaml
```

This will inspect dependencies and download schemas that provide intellisense into vscode

this will create the functions directory structure. in our example {function-name} was specified as 'containerworkflow'

```shell
functions/
└── containerworkflow
    ├── kcl.mod
    ├── kcl.mod.lock
    ├── main.k
    ├── model -> ../../.up/kcl/models
```

Since we use kcl, we modify the main.k file as the main file, to suite our leads.

The main.k includes the imported dependencies, and variables such as:
- oxr:      Observed composite resource
- _ocds:    Observed composed resources
- _dxr:     Desired composite resources
- dcds:     Desired composed resources

We also have the default _items: [] array, ready for creating resources.

We can begin to create our kcl resources now, we specify the resource type by prefixing with the imported module name.

Example

```kcl
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
]

items = _items
```

The pre-generated main.k template includes a standard lambda:

```kcl
_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}
```

This lambda performs a function with krm.

We can build the project, using `up project build` which will create our configuration package xpkg file:

```shell
_output/
└── containerworkflow.uppkg
```

We do not push using `up project push` as we are not integrated with upbound cloud services.
