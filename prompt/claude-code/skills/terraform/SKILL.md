# Terraform — Declarative Infrastructure as Code

HashiCorp Terraform is an infrastructure as code (IaC) tool that lets you define cloud and on-premises resources in human-readable HCL configuration files. Terraform uses a declarative approach: you describe the desired end state, and Terraform computes the dependency graph (DAG) and execution plan to reach it. Key features include multi-cloud provider support via a plugin-based architecture, state management for tracking real-world resource mappings, plan/apply workflow for safe change previews, modules for reusable infrastructure components, and workspaces for managing multiple environments.

## When to use this skill

- Writing or reviewing Terraform HCL configuration (resources, data sources, modules, providers)
- Understanding Terraform CLI commands (init, plan, apply, destroy, import, state)
- Configuring backends for remote state storage (S3, GCS, Azure, Consul, Kubernetes, etc.)
- Working with Terraform expressions, functions, and type system
- Designing module composition and structure
- Managing state operations (move, import, taint, remove, refactor)
- Debugging Terraform plans, dependency graphs, or provider issues
- Comparing Terraform with alternatives (CloudFormation, Chef/Puppet, Pulumi)
- Configuring HCP Terraform (Terraform Cloud) or Terraform Enterprise integrations
- Working with Terraform Stacks for multi-deployment orchestration

---

## Additional Resources

### Introduction & Overview
- [What is Terraform](intro/index.mdx) — Core concepts: how Terraform works, providers, and the write/plan/apply lifecycle
- [Core Terraform Workflow](intro/core-workflow.mdx) — The Write, Plan, Apply workflow for individuals, teams, and organizations
- [Use Cases](intro/use-cases.mdx) — Multi-cloud deployments, application management, policy compliance, self-service infrastructure
- [Terraform Editions](intro/terraform-editions.mdx) — Community Edition vs HCP Terraform vs Terraform Enterprise
- [Phases of Terraform Adoption](intro/phases/index.mdx) — Overview of adoption phases
  - [Adopt](intro/phases/adopt.mdx) — Getting started with Terraform
  - [Collaborate](intro/phases/collaborate.mdx) — Team workflows
  - [Govern](intro/phases/govern.mdx) — Policy and governance
  - [Scale](intro/phases/scale.mdx) — Scaling infrastructure management

### Introduction: Comparisons
- [Terraform vs Alternatives Overview](intro/vs/index.mdx) — Overview of comparisons
- [Terraform vs CloudFormation/Heat](intro/vs/cloudformation.mdx) — Comparing with AWS CloudFormation and OpenStack Heat
- [Terraform vs Chef/Puppet](intro/vs/chef-puppet.mdx) — Comparing with configuration management tools
- [Terraform vs Boto/Fog](intro/vs/boto.mdx) — Comparing with cloud client libraries
- [Terraform vs Custom Solutions](intro/vs/custom.mdx) — Comparing with in-house tooling

### CLI: Overview & Configuration
- [Terraform CLI Documentation](cli/index.mdx) — CLI documentation overview
- [CLI Configuration Overview](cli/config/index.mdx) — CLI configuration files and settings
- [CLI Configuration File](cli/config/config-file.mdx) — Create and configure the `.terraformrc` file
- [Environment Variables](cli/config/environment-variables.mdx) — `TF_LOG`, `TF_VAR_*`, and other environment variables

### CLI: Core Commands
- [CLI Overview](cli/commands/index.mdx) — Summary of all Terraform commands
- [terraform init](cli/commands/init.mdx) — Initialize a working directory with providers and modules
- [terraform plan](cli/commands/plan.mdx) — Preview infrastructure changes
- [terraform apply](cli/commands/apply.mdx) — Apply changes to reach desired state
- [terraform destroy](cli/commands/destroy.mdx) — Destroy all managed infrastructure
- [terraform validate](cli/commands/validate.mdx) — Check configuration syntax and consistency
- [terraform fmt](cli/commands/fmt.mdx) — Reformat configuration to canonical style
- [terraform show](cli/commands/show.mdx) — Display state or plan in human-readable form
- [terraform output](cli/commands/output.mdx) — Read output values from state
- [terraform console](cli/commands/console.mdx) — Interactive expression evaluation
- [terraform graph](cli/commands/graph.mdx) — Generate a visual dependency graph (DOT format)
- [terraform import](cli/commands/import.mdx) — Import existing resources into state
- [terraform refresh](cli/commands/refresh.mdx) — Reconcile state with real infrastructure
- [terraform test](cli/commands/test.mdx) — Run integration tests against configuration
- [terraform get](cli/commands/get.mdx) — Download and update modules
- [terraform login](cli/commands/login.mdx) — Authenticate with HCP Terraform
- [terraform logout](cli/commands/logout.mdx) — Remove stored credentials
- [terraform version](cli/commands/version.mdx) — Display Terraform version
- [terraform taint](cli/commands/taint.mdx) — Mark a resource for recreation (deprecated)
- [terraform untaint](cli/commands/untaint.mdx) — Remove taint from a resource
- [terraform force-unlock](cli/commands/force-unlock.mdx) — Manually unlock state
- [terraform modules](cli/commands/modules.mdx) — List modules used in configuration
- [terraform query](cli/commands/query.mdx) — Query configuration using `.tfquery.hcl` files
- [terraform 0.12upgrade](cli/commands/0.12upgrade.mdx) — Upgrade syntax from v0.11 to v0.12
- [terraform 0.13upgrade](cli/commands/0.13upgrade.mdx) — Upgrade provider requirements for v0.13

### CLI: Providers Commands
- [terraform providers](cli/commands/providers.mdx) — Show required providers
- [terraform providers lock](cli/commands/providers/lock.mdx) — Write provider dependency lockfile
- [terraform providers mirror](cli/commands/providers/mirror.mdx) — Mirror providers for air-gapped use
- [terraform providers schema](cli/commands/providers/schema.mdx) — Show provider schemas as JSON

### CLI: State Commands
- [terraform state overview](cli/commands/state/index.mdx) — State manipulation commands
- [terraform state list](cli/commands/state/list.mdx) — List resources in state
- [terraform state show](cli/commands/state/show.mdx) — Show a single resource in state
- [terraform state mv](cli/commands/state/mv.mdx) — Move resources within or between states
- [terraform state rm](cli/commands/state/rm.mdx) — Remove resources from state
- [terraform state pull](cli/commands/state/pull.mdx) — Fetch current remote state
- [terraform state push](cli/commands/state/push.mdx) — Push local state to remote
- [terraform state replace-provider](cli/commands/state/replace-provider.mdx) — Replace provider in state

### CLI: Workspace Commands
- [terraform workspace overview](cli/commands/workspace/index.mdx) — Manage workspaces
- [terraform workspace new](cli/commands/workspace/new.mdx) — Create a new workspace
- [terraform workspace select](cli/commands/workspace/select.mdx) — Switch to a workspace
- [terraform workspace list](cli/commands/workspace/list.mdx) — List available workspaces
- [terraform workspace show](cli/commands/workspace/show.mdx) — Show current workspace
- [terraform workspace delete](cli/commands/workspace/delete.mdx) — Delete a workspace

### CLI: Stacks Commands
- [terraform stacks overview](cli/commands/stacks/index.mdx) — Multi-component deployment orchestration
- [terraform stacks global flags](cli/commands/stacks/global-flags.mdx) — Global flags for stacks commands
- [terraform stacks create](cli/commands/stacks/create.mdx) — Create a new stack
- [terraform stacks init](cli/commands/stacks/init.mdx) — Initialize a stack
- [terraform stacks list](cli/commands/stacks/list.mdx) — List stacks
- [terraform stacks fmt](cli/commands/stacks/fmt.mdx) — Format stack configuration
- [terraform stacks validate](cli/commands/stacks/validate.mdx) — Validate stack configuration
- [terraform stacks version](cli/commands/stacks/version.mdx) — Show stacks CLI version
- [terraform stacks providers lock](cli/commands/stacks/providers-lock.mdx) — Lock providers for stacks
- [Stacks Configuration Commands](cli/commands/stacks/configuration/index.mdx) — Manage stack configurations
  - [fetch](cli/commands/stacks/configuration/fetch.mdx), [list](cli/commands/stacks/configuration/list.mdx), [upload](cli/commands/stacks/configuration/upload.mdx), [watch](cli/commands/stacks/configuration/watch.mdx)
- [Stacks Deployment Group Commands](cli/commands/stacks/deployment-group/index.mdx) — Manage deployment groups
  - [list](cli/commands/stacks/deployment-group/list.mdx), [approve-all-plans](cli/commands/stacks/deployment-group/approve-all-plans.mdx), [rerun](cli/commands/stacks/deployment-group/rerun.mdx), [watch](cli/commands/stacks/deployment-group/watch.mdx)
- [Stacks Deployment Run Commands](cli/commands/stacks/deployment-run/index.mdx) — Manage deployment runs
  - [list](cli/commands/stacks/deployment-run/list.mdx), [approve-all-plans](cli/commands/stacks/deployment-run/approve-all-plans.mdx), [cancel](cli/commands/stacks/deployment-run/cancel.mdx), [watch](cli/commands/stacks/deployment-run/watch.mdx)

### CLI: Workflows & Guides
- [Authentication (API Tokens)](cli/auth/index.mdx) — Obtain API tokens for HCP Terraform / Terraform Enterprise
- [HCP Terraform Integration](cli/cloud/index.mdx) — Use HCP Terraform with the CLI
- [Cloud Command-Line Arguments](cli/cloud/command-line-arguments.mdx) — `-ignore-remote-version` reference
- [Cloud Settings](cli/cloud/settings.mdx) — Connect to HCP Terraform
- [Format and Validate](cli/code/index.mdx) — Format and validate configuration
- [Import Existing Infrastructure](cli/import/index.mdx) — Import overview
- [Import Usage](cli/import/usage.mdx) — Step-by-step import instructions
- [Initialize Working Directory](cli/init/index.mdx) — Initialization details
- [Inspect Infrastructure](cli/inspect/index.mdx) — Inspect current infrastructure state
- [Manage Plugins](cli/plugins/index.mdx) — Plugin management and caching
- [Plugin Signatures](cli/plugins/signing.mdx) — Provider signing and trust
- [Provisioning Workflow](cli/run/index.mdx) — End-to-end provisioning workflow
- [State Management](cli/state/index.mdx) — Manual state manipulation overview
- [Inspect State](cli/state/inspect.mdx) — Read and inspect state data
- [Move Resources](cli/state/move.mdx) — Move resources between modules or states
- [Recover State](cli/state/recover.mdx) — Recover state from backups
- [Resource Addressing](cli/state/resource-addressing.mdx) — Resource address syntax reference
- [Taint/Recreate Resources](cli/state/taint.mdx) — Force resource recreation
- [Testing Features](cli/test/index.mdx) — Terraform testing overview
- [Manage Workspaces](cli/workspaces/index.mdx) — Workspace management guide

### Language: Overview & Syntax
- [Terraform Language Documentation](language/index.mdx) — Configuration language overview
- [Syntax Overview](language/syntax/index.mdx) — HCL syntax fundamentals
- [Configuration Syntax](language/syntax/configuration.mdx) — Blocks, arguments, and expressions
- [JSON Syntax](language/syntax/json.mdx) — JSON-based configuration alternative
- [Style Guide](language/style.mdx) — HCL style conventions
- [Files and Structure](language/files/index.mdx) — File organization and naming
- [Override Files](language/files/override.mdx) — Override configuration in separate files
- [Dependency Lock File](language/files/dependency-lock.mdx) — `.terraform.lock.hcl` reference
- [Stack Configuration Files](language/files/stack.mdx) — Stack file structure
- [Test Files](language/files/tests.mdx) — `.tftest.hcl` file format
- [Query Files](language/files/tfquery.mdx) — `.tfquery.hcl` file format
- [Attributes as Blocks](language/attr-as-blocks.mdx) — Legacy attribute-as-block syntax

### Language: Configuration Blocks
- [resource](language/block/resource.mdx) — Define infrastructure resources
- [data](language/block/data.mdx) — Query external data sources
- [provider](language/block/provider.mdx) — Configure providers
- [variable](language/block/variable.mdx) — Declare input variables
- [output](language/block/output.mdx) — Expose values from modules
- [locals](language/block/locals.mdx) — Define local values
- [module](language/block/module.mdx) — Call reusable modules
- [terraform](language/block/terraform.mdx) — Configure Terraform settings and required providers
- [import](language/block/import.mdx) — Declarative resource import
- [moved](language/block/moved.mdx) — Refactor resources without destroy/recreate
- [removed](language/block/removed.mdx) — Remove resources from configuration
- [check](language/block/check.mdx) — Post-apply assertions and health checks
- [ephemeral](language/block/ephemeral.mdx) — Ephemeral resources for sensitive/temporary data
- [action](language/block/action.mdx) — Define invocable actions
- [tfquery list](language/block/tfquery/list.mdx) — List block for query files

### Language: Stack Blocks (Component)
- [Component Configuration Overview](language/block/stack/tfcomponent/index.mdx) — Component config structure
- [component](language/block/stack/tfcomponent/component.mdx) — Define stack components
- [output](language/block/stack/tfcomponent/output.mdx) — Component outputs
- [provider](language/block/stack/tfcomponent/provider.mdx) — Component providers
- [removed](language/block/stack/tfcomponent/removed.mdx) — Remove components
- [required_providers](language/block/stack/tfcomponent/required_providers.mdx) — Component provider requirements
- [stack](language/block/stack/tfcomponent/stack.mdx) — Stack block reference
- [variable](language/block/stack/tfcomponent/variable.mdx) — Component variables

### Language: Stack Blocks (Deployment)
- [Deployment Configuration Overview](language/block/stack/tfdeploy/index.mdx) — Deployment config structure
- [deployment](language/block/stack/tfdeploy/deployment.mdx) — Define deployments
- [deployment_auto_approve](language/block/stack/tfdeploy/deployment_auto_approve.mdx) — Auto-approve settings
- [deployment_group](language/block/stack/tfdeploy/deployment_group.mdx) — Deployment groups
- [identity_token](language/block/stack/tfdeploy/identity_token.mdx) — Identity tokens for auth
- [publish_output](language/block/stack/tfdeploy/publish_output.mdx) — Publish outputs between stacks
- [store](language/block/stack/tfdeploy/store.mdx) — Store block for state
- [upstream_input](language/block/stack/tfdeploy/upstream_input.mdx) — Consume upstream stack outputs

### Language: Expressions
- [Expressions Overview](language/expressions/index.mdx) — Expression syntax and evaluation
- [Types and Values](language/expressions/types.mdx) — Terraform type system
- [Type Constraints](language/expressions/type-constraints.mdx) — Constraining variable types
- [Strings and Templates](language/expressions/strings.mdx) — String interpolation and heredocs
- [References to Values](language/expressions/references.mdx) — Referencing resources, variables, and outputs
- [Operators](language/expressions/operators.mdx) — Arithmetic and logical operators
- [Conditional Expressions](language/expressions/conditionals.mdx) — Ternary conditionals
- [For Expressions](language/expressions/for.mdx) — List and map comprehensions
- [Splat Expressions](language/expressions/splat.mdx) — Compact iteration syntax
- [Dynamic Blocks](language/expressions/dynamic-blocks.mdx) — Dynamically generate nested blocks
- [Function Calls](language/expressions/function-calls.mdx) — Calling built-in functions
- [Version Constraints](language/expressions/version-constraints.mdx) — Version constraint syntax

### Language: Built-in Functions
- [Functions Overview](language/functions/index.mdx) — Complete function reference index
- **Numeric:** [abs](language/functions/abs.mdx), [ceil](language/functions/ceil.mdx), [floor](language/functions/floor.mdx), [log](language/functions/log.mdx), [max](language/functions/max.mdx), [min](language/functions/min.mdx), [parseint](language/functions/parseint.mdx), [pow](language/functions/pow.mdx), [signum](language/functions/signum.mdx), [sum](language/functions/sum.mdx)
- **String:** [chomp](language/functions/chomp.mdx), [endswith](language/functions/endswith.mdx), [format](language/functions/format.mdx), [formatlist](language/functions/formatlist.mdx), [indent](language/functions/indent.mdx), [join](language/functions/join.mdx), [lower](language/functions/lower.mdx), [regex](language/functions/regex.mdx), [regexall](language/functions/regexall.mdx), [replace](language/functions/replace.mdx), [split](language/functions/split.mdx), [startswith](language/functions/startswith.mdx), [strcontains](language/functions/strcontains.mdx), [strrev](language/functions/strrev.mdx), [substr](language/functions/substr.mdx), [templatefile](language/functions/templatefile.mdx), [templatestring](language/functions/templatestring.mdx), [title](language/functions/title.mdx), [trim](language/functions/trim.mdx), [trimprefix](language/functions/trimprefix.mdx), [trimsuffix](language/functions/trimsuffix.mdx), [trimspace](language/functions/trimspace.mdx), [upper](language/functions/upper.mdx)
- **Collection:** [chunklist](language/functions/chunklist.mdx), [coalesce](language/functions/coalesce.mdx), [coalescelist](language/functions/coalescelist.mdx), [compact](language/functions/compact.mdx), [concat](language/functions/concat.mdx), [contains](language/functions/contains.mdx), [distinct](language/functions/distinct.mdx), [element](language/functions/element.mdx), [flatten](language/functions/flatten.mdx), [index](language/functions/index_function.mdx), [keys](language/functions/keys.mdx), [length](language/functions/length.mdx), [list](language/functions/list.mdx), [lookup](language/functions/lookup.mdx), [map](language/functions/map.mdx), [matchkeys](language/functions/matchkeys.mdx), [merge](language/functions/merge.mdx), [one](language/functions/one.mdx), [range](language/functions/range.mdx), [reverse](language/functions/reverse.mdx), [setintersection](language/functions/setintersection.mdx), [setproduct](language/functions/setproduct.mdx), [setsubtract](language/functions/setsubtract.mdx), [setunion](language/functions/setunion.mdx), [slice](language/functions/slice.mdx), [sort](language/functions/sort.mdx), [transpose](language/functions/transpose.mdx), [values](language/functions/values.mdx), [zipmap](language/functions/zipmap.mdx)
- **Encoding:** [base64decode](language/functions/base64decode.mdx), [base64encode](language/functions/base64encode.mdx), [base64gzip](language/functions/base64gzip.mdx), [csvdecode](language/functions/csvdecode.mdx), [jsondecode](language/functions/jsondecode.mdx), [jsonencode](language/functions/jsonencode.mdx), [textdecodebase64](language/functions/textdecodebase64.mdx), [textencodebase64](language/functions/textencodebase64.mdx), [urlencode](language/functions/urlencode.mdx), [yamldecode](language/functions/yamldecode.mdx), [yamlencode](language/functions/yamlencode.mdx)
- **Filesystem:** [abspath](language/functions/abspath.mdx), [basename](language/functions/basename.mdx), [dirname](language/functions/dirname.mdx), [file](language/functions/file.mdx), [filebase64](language/functions/filebase64.mdx), [fileexists](language/functions/fileexists.mdx), [fileset](language/functions/fileset.mdx), [pathexpand](language/functions/pathexpand.mdx), [templatefile](language/functions/templatefile.mdx)
- **Hash & Crypto:** [base64sha256](language/functions/base64sha256.mdx), [base64sha512](language/functions/base64sha512.mdx), [bcrypt](language/functions/bcrypt.mdx), [filebase64sha256](language/functions/filebase64sha256.mdx), [filebase64sha512](language/functions/filebase64sha512.mdx), [filemd5](language/functions/filemd5.mdx), [filesha1](language/functions/filesha1.mdx), [filesha256](language/functions/filesha256.mdx), [filesha512](language/functions/filesha512.mdx), [md5](language/functions/md5.mdx), [rsadecrypt](language/functions/rsadecrypt.mdx), [sha1](language/functions/sha1.mdx), [sha256](language/functions/sha256.mdx), [sha512](language/functions/sha512.mdx), [uuid](language/functions/uuid.mdx), [uuidv5](language/functions/uuidv5.mdx)
- **IP Network:** [cidrhost](language/functions/cidrhost.mdx), [cidrnetmask](language/functions/cidrnetmask.mdx), [cidrsubnet](language/functions/cidrsubnet.mdx), [cidrsubnets](language/functions/cidrsubnets.mdx)
- **Date/Time:** [formatdate](language/functions/formatdate.mdx), [plantimestamp](language/functions/plantimestamp.mdx), [timeadd](language/functions/timeadd.mdx), [timecmp](language/functions/timecmp.mdx), [timestamp](language/functions/timestamp.mdx)
- **Type Conversion:** [can](language/functions/can.mdx), [tobool](language/functions/tobool.mdx), [tolist](language/functions/tolist.mdx), [tomap](language/functions/tomap.mdx), [tonumber](language/functions/tonumber.mdx), [toset](language/functions/toset.mdx), [tostring](language/functions/tostring.mdx), [try](language/functions/try.mdx), [type](language/functions/type.mdx)
- **Sensitive Data:** [sensitive](language/functions/sensitive.mdx), [nonsensitive](language/functions/nonsensitive.mdx), [issensitive](language/functions/issensitive.mdx), [ephemeralasnull](language/functions/ephemeralasnull.mdx)
- **Terraform-specific:** [terraform.applying](language/functions/terraform-applying.mdx), [decode_tfvars](language/functions/terraform-decode_tfvars.mdx), [encode_expr](language/functions/terraform-encode_expr.mdx), [encode_tfvars](language/functions/terraform-encode_tfvars.mdx)
- **Boolean:** [alltrue](language/functions/alltrue.mdx), [anytrue](language/functions/anytrue.mdx)

### Language: Resources & Data Sources
- [Resources Overview](language/resources/index.mdx) — Creating and managing resources
- [Configure a Resource](language/resources/configure.mdx) — Resource block arguments and behavior
- [Destroy a Resource](language/resources/destroy.mdx) — Resource destruction lifecycle
- [terraform_data Resource](language/resources/terraform-data.mdx) — Trigger-based resource for arbitrary data
- [Data Sources](language/data-sources/index.mdx) — Query external data for use in configuration

### Language: Meta-Arguments
- [Meta-Arguments Overview](language/meta-arguments/index.mdx) — Arguments applicable to all resource types
- [count](language/meta-arguments/count.mdx) — Create multiple instances by count
- [for_each](language/meta-arguments/for_each.mdx) — Create instances from a map or set
- [depends_on](language/meta-arguments/depends_on.mdx) — Explicit dependency declaration
- [lifecycle](language/meta-arguments/lifecycle.mdx) — Customize resource lifecycle (create_before_destroy, prevent_destroy, ignore_changes)
- [provider](language/meta-arguments/provider.mdx) — Select a non-default provider
- [providers](language/meta-arguments/providers.mdx) — Pass providers to child modules

### Language: Modules
- [Modules Overview](language/modules/index.mdx) — What modules are and how they work
- [Use Modules in Configuration](language/modules/configuration.mdx) — Calling modules in your config
- [Module Sources](language/modules/sources.mdx) — Registry, GitHub, S3, GCS, and local sources
- [Creating Modules](language/modules/develop/index.mdx) — Module development guide
- [Module Composition](language/modules/develop/composition.mdx) — Composing modules together
- [Standard Module Structure](language/modules/develop/structure.mdx) — File layout conventions
- [Providers Within Modules](language/modules/develop/providers.mdx) — Provider configuration in modules
- [Publishing Modules](language/modules/develop/publish.mdx) — Publishing to the Terraform Registry
- [Refactoring Modules](language/modules/develop/refactoring.mdx) — Restructuring without state loss

### Language: Providers
- [Providers Overview](language/providers/index.mdx) — Provider plugins and configuration
- [Provider Requirements](language/providers/requirements.mdx) — Declaring required providers and versions

### Language: Backends
- [Backend Overview](language/backend/index.mdx) — State storage backend configuration
- [local](language/backend/local.mdx), [s3](language/backend/s3.mdx), [gcs](language/backend/gcs.mdx), [azurerm](language/backend/azurerm.mdx), [consul](language/backend/consul.mdx), [cos](language/backend/cos.mdx), [http](language/backend/http.mdx), [kubernetes](language/backend/kubernetes.mdx), [oci](language/backend/oci.mdx), [oss](language/backend/oss.mdx), [pg](language/backend/pg.mdx), [remote](language/backend/remote.mdx)

### Language: State
- [State Overview](language/state/index.mdx) — What state is and why it matters
- [Purpose of State](language/state/purpose.mdx) — Mapping configuration to real resources
- [Backends: Storage and Locking](language/state/backends.mdx) — Backend state storage
- [State Locking](language/state/locking.mdx) — Preventing concurrent modifications
- [Remote State Storage](language/state/remote.mdx) — Storing state remotely
- [Remote State Data Source](language/state/remote-state-data.mdx) — `terraform_remote_state` for cross-project references
- [Import Existing Resources](language/state/import.mdx) — Importing into state
- [Refactor State](language/state/refactor.mdx) — Restructuring state
- [Remove from State](language/state/remove.mdx) — Removing resources from state tracking
- [Workspaces](language/state/workspaces.mdx) — Multiple state instances per configuration

### Language: Import
- [Import Overview](language/import/index.mdx) — Importing existing resources
- [Import Single Resource](language/import/single-resource.mdx) — Import one resource
- [Bulk Import](language/import/bulk.mdx) — Import multiple resources at once
- [Generating Configuration](language/import/generating-configuration.mdx) — Auto-generate HCL from imported resources

### Language: Sensitive Data
- [Manage Sensitive Data](language/manage-sensitive-data/index.mdx) — Overview of sensitive data handling
- [Ephemeral Values](language/manage-sensitive-data/ephemeral.mdx) — Ephemeral values in resources
- [Write-Only Arguments](language/manage-sensitive-data/write-only.mdx) — Temporary write-only arguments

### Language: Values
- [Values Overview](language/values/index.mdx) — Managing values in modules
- [Input Variables](language/values/variables.mdx) — Parameterize modules with variables
- [Output Values](language/values/outputs.mdx) — Expose data from modules
- [Local Values](language/values/locals.mdx) — Reuse expressions with locals

### Language: Stacks
- [Stacks Overview](language/stacks/index.mdx) — Multi-component deployment orchestration
- [Design a Stack](language/stacks/design.mdx) — Architecture and design patterns
- [Use Cases](language/stacks/use-cases.mdx) — When to use stacks
- [Update from Beta to GA](language/stacks/update-GA.mdx) — Migration guide
- [Component Configuration](language/stacks/component/config.mdx) — Define component config
- [Declare Providers](language/stacks/component/declare-providers.mdx) — Provider declarations in components
- [Manage Components](language/stacks/component/manage.mdx) — Component lifecycle management
- [Authenticate a Stack](language/stacks/deploy/authenticate.mdx) — Authentication for deployments
- [Deployment Conditions](language/stacks/deploy/conditions.mdx) — Conditional deployment runs
- [Deployment Configuration](language/stacks/deploy/config.mdx) — Deployment config reference
- [Pass Data Between Stacks](language/stacks/deploy/pass-data.mdx) — Cross-stack data sharing

### Language: Testing, Validation & Provisioners
- [Tests Overview](language/tests/index.mdx) — Write and run Terraform tests
- [Provider Mocking](language/tests/mocking.mdx) — Mock providers in tests
- [Validation](language/validate/index.mdx) — Validate infrastructure configuration
- [Provisioners](language/provisioners.mdx) — Post-apply operations (local-exec, remote-exec)
- [Invoke Actions](language/invoke-actions.mdx) — Invoke defined actions

### Language: Upgrades & Compatibility
- [Upgrade Guide (v1.12)](language/upgrade-guides/index.mdx) — Breaking changes and migration
- [v1.x Compatibility Promises](language/v1-compatibility-promises.mdx) — Stability guarantees

### Internals
- [Internals Overview](internals/index.mdx) — How Terraform works under the hood
- [Dependency Graph](internals/graph.mdx) — Resource dependency DAG construction
- [JSON Output Format](internals/json-format.mdx) — Machine-readable JSON plan/state format
- [Machine-Readable UI](internals/machine-readable-ui.mdx) — Structured output for automation
- [Debugging (TF_LOG)](internals/debugging.mdx) — Enable and configure debug logging
- [Credentials Helpers](internals/credentials-helpers.mdx) — Custom credential storage plugins
- [Archiving Providers](internals/archiving.mdx) — Provider archival process
- [Provider Metadata](internals/provider-meta.mdx) — Collect provider metadata
- [Functions Metadata](internals/functions-meta.mdx) — `terraform metadata functions` command
- [Login Protocol](internals/login-protocol.mdx) — OAuth-based login protocol
- [Remote Service Discovery](internals/remote-service-discovery.mdx) — `.well-known/terraform.json` discovery
- [Module Registry Protocol](internals/module-registry-protocol.mdx) — Module registry API specification
- [Provider Registry Protocol](internals/provider-registry-protocol.mdx) — Provider registry API specification
- [Provider Network Mirror Protocol](internals/provider-network-mirror-protocol.mdx) — Air-gapped provider distribution

### Partials (Reusable Fragments)
- [Beta Notice](partials/beta.mdx) — Beta feature disclaimer
- [Module Source Git Details](partials/module-block-source-arg-git-details.mdx) — Git source argument details
- [Premium Deployment Groups](partials/premium-deployment-groups.mdx) — Premium tier deployment groups notice
- [Provisioner Connection Settings](partials/provisioner-connnection-settings.mdx) — SSH/WinRM connection configuration
