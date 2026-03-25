# Applying Sheet Diagrams to Terraform / IaC

## Status: Research / design discussion (not yet implemented)

## The Natural Correspondence

| Clinical system | Terraform/IaC |
|---|---|
| `Patient "Jose"` | `aws_instance "web"` |
| `Clinician "Allen"` | `aws_security_group "allow_http"` |
| `ExamBed`, `BPMonitor` | `aws_ebs_volume`, `aws_elastic_ip` |
| Trial / Clinic / Room scopes | Account / VPC / Subnet scopes |
| `SharedLangEvidence` | `SecurityGroupAllowsTraffic src dst port` |
| `ClinicCityEvidence` | `SubnetInVPC subnet vpc` or `CIDRContainment child parent` |
| `holdsExamBedQual` | `IAMPolicyGrantsPermission role action resource` |
| KB (Neo4j) ground facts | `terraform state pull` + cloud API reads |
| `Erased.Pipeline` | Terraform HCL / plan |
| Arrow steps | Resource creation/modification operations |
| Branching | Conditional infra (multi-AZ? public/private? ALB/NLB?) |

## What's Gained — Real Bugs This Would Catch

The constraint system becomes much more valuable for IaC than for clinical trials, because network misconfiguration is the #1 source of cloud security incidents.

### Scope-level constraints that mirror real policies

- *VPC scope* declares `.constraint .noPublicSSH` — fires when any security group tagged `.ingressRule` allows port 22 from `0.0.0.0/0`
- *Production scope* declares `.constraint .encryptionAtRest` — fires when any EBS volume or RDS instance enters scope, requiring `EncryptionEvidence`
- *Subnet scope* declares `.constraint .cidrContainment` — the subnet CIDR must fit within the parent VPC CIDR

### The George test becomes the killer feature

"George at ParisClinic" maps to "public-facing database in a private subnet with no NAT gateway" — the obligations are unprovable because the route doesn't exist. The Terraform plan *cannot be generated* until the constraint is satisfied. This is policy-as-types, enforced before `terraform apply`.

### Role-indexed constraints carry over directly

An `aws_instance` tagged `.webServer` needs HTTP ingress; one tagged `.databaseServer` needs only port 5432 from the app subnet. The `.webServer` constraint doesn't fire for `.databaseServer` entries — same mechanism as `.bpTech` vs `.vo2Tech`.

## What's Hard — Where the Architecture Needs Extension

### 1. Resource attributes and inter-resource references

Clinical resources are simple (name-indexed unit types). Terraform resources have structured attributes, and they reference each other:

```
aws_instance.web.subnet_id = aws_subnet.public.id
```

The current `Ctx = List Type` would need to become richer — either dependent types with attribute fields, or a separate attribute graph. The telescope system (`Tel`) already supports dependency; it would need to be used more heavily. This is the biggest structural change.

### 2. The constraint language is richer

CIDR arithmetic (`10.0.1.0/24 ⊂ 10.0.0.0/16`), port range overlap, IAM policy evaluation — these are all decidable but non-trivial to formalize. You'd want:

```lean
structure CIDRContainment (child parent : String) : Type where
  childCIDR  : CIDR
  parentCIDR : CIDR
  proof      : childCIDR.isSubnetOf parentCIDR = true
```

The good news: all of these are `Decidable`, so `native_decide` handles the proofs automatically once the facts are stated. The clinical system already does this pattern — the proof terms are trivial (`.mk`); the structure is what matters.

### 3. The scope hierarchy is deeper and more varied

Clinical has 3 levels (trial → clinic → room). IaC has many: Organization → Account → Region → VPC → Subnet → Security Group → Instance. But `ScopeState` is already a flat stack — deeper nesting just means more `ScopeItem` pushes. The architecture handles this without change.

### 4. State reading replaces manual KB construction

The clinical KB is hand-written (`allen_speaks_spanish := .mk`). For Terraform, you'd read the state file and generate `ScopeItem` lists + ground facts automatically. This is the "KB derivation" design note at the bottom of the plan — it's the same problem, just with a different data source.

## The Implementation Path

### Phase 1 — Domain types

Replace clinical types with IaC types. `Tag` gets variants like `.vpc`, `.subnet`, `.securityGroup`, `.instance`, `.iamRole`. `ConstraintId` gets `.cidrContainment`, `.routeExists`, `.securityGroupAllows`, `.iamPermission`. The `Scope.lean` / `Clinical.lean` split already separates domain-agnostic machinery from domain types — you'd write a new `Terraform.lean` alongside `Clinical.lean`.

### Phase 2 — State import

A function `terraformStateToScopeItems : JSON → List ScopeItem × Ctx` that reads `terraform state pull` output and generates scope items with tags + a context with typed resources. This replaces the Neo4j seeding step.

### Phase 3 — Erasure to HCL

`Erased.Pipeline` already carries step names and scope labels. A `toHCL : Pipeline → String` function would emit Terraform configuration. The scope labels become resource blocks; the step names become resource definitions.

### Phase 4 — LLM-driven plan generation

The n8n Designer/Prover workflow already exists for clinical pipelines. The same 2-pass approach works: LLM designs the infrastructure topology (which resources, which scopes), Lean verifies it type-checks with all constraints satisfied.

## What Makes This Interesting Theoretically

The sheet diagram decomposition matters more for IaC than for clinical trials. Real infrastructure has genuine branching: blue/green deployments, canary releases, failover paths. These are not just "consent or refuse" — they're persistent architectural alternatives that coexist. The `List Ctx` output (multiple possible outcome contexts) maps to "these are the possible states your infrastructure could be in after this operation." Joins correspond to convergence points where different deployment strategies reach the same steady state.

The re-planning story (paper Section 9.2) becomes **drift remediation**: current state diverges from desired state, you reflect the actual infrastructure into `Δ_current`, and derive a new pipeline `Δ_current → Δ_desired`. The type checker verifies the remediation plan is valid from where you actually are, not from where you thought you were.

## Where Our System Adds Value Over Existing Tools

Checkov/tfsec/OPA all operate on the **plan** — they scan a Terraform file and flag violations. Our system would operate on the **specification** — you can't even *construct* a violating plan.

| Existing tools | Our approach |
|---|---|
| Scan after writing, report violations | Can't write an invalid config — type error |
| Each rule is independent | Constraints compose across scopes |
| No notion of "this VPC scope forbids X" | Scope-level policy declaration, fires when resources enter |
| Flat rule set | Hierarchical: org → account → VPC → subnet constraints inherit |
| Runtime check | Compile-time guarantee |

## Sources of Terraform with Known Errors

### Intentionally vulnerable repos (test cases)

- **TerraGoat** (https://github.com/bridgecrewio/terragoat) — Bridgecrew's "vulnerable by design" Terraform. AWS, Azure, GCP configs with labeled misconfigurations. Probably the single best starting point — every file is a concrete "George at ParisClinic" that should fail to type-check.
- **IAM Vulnerable** (https://github.com/BishopFox/iam-vulnerable) — 250+ IAM privilege escalation scenarios in Terraform. Focuses on the permission constraint domain.
- **SadCloud** (https://github.com/nccgroup/sadcloud) — NCC Group's tool: ~84 misconfigurations across 22 AWS services. Well-organized by service.
- **terraform-vulnerability-lab** (https://github.com/pgarcia1980/terraform-vulnerability-lab) — Educational, designed to be scanned with tfsec.

### Real-world error data (academic)

- Rahman et al. (2023) "Exploring Security Practices in IaC" (https://arxiv.org/abs/2308.03952) — empirical study of 812 open-source Terraform projects on GitHub.
- PMC study on security policy adoption (https://pmc.ncbi.nlm.nih.gov/articles/PMC11868142/) — 292,538 security violations in 8,256 public repos. Top vulnerable resources: instances, modules, security groups, S3 buckets.
- LLM-generated Terraform error taxonomy (https://arxiv.org/html/2512.14792) — 19 error types in LLM-generated Terraform.

## Sources of Good Constraints

### Definitive constraint catalogs

- **Checkov policy index** (https://www.checkov.io/5.Policy%20Index/terraform.html) — ~1,000 named rules across AWS/Azure/GCP. Each rule is a `ConstraintId` candidate. Examples:
  - `CKV_AWS_24`: No SSH from 0.0.0.0/0 → `.constraint .noPublicSSH`
  - `CKV_AWS_19`: S3 server-side encryption → `.constraint .s3Encrypted`
  - `CKV_AWS_20`: S3 not public → `.constraint .s3NotPublic`
  - `CKV_AWS_260`: No HTTP from 0.0.0.0/0 → `.constraint .noPublicHTTP`

- **HashiCorp CIS Policy Set for AWS** (https://registry.terraform.io/policies/hashicorp/CIS-Policy-Set-for-AWS-Terraform/latest) — Sentinel policies implementing CIS AWS Foundations Benchmark. Pre-formalized constraints with clear pass/fail semantics.

- **nozaq/terraform-aws-secure-baseline** (https://github.com/nozaq/terraform-aws-secure-baseline) — Terraform module implementing CIS + AWS Foundational Security Best Practices.

### Policy-as-code frameworks (existing art)

- Spacelift: Policy as Code with Sentinel & OPA (https://spacelift.io/blog/terraform-policy-as-code)
- OPA with Terraform examples (https://spacelift.io/blog/open-policy-agent-opa-terraform)
- Scalr: Enforcing Policy as Code (https://scalr.com/learning-center/enforcing-policy-as-code-in-terraform-a-comprehensive-guide/)

## Suggested Starting Point

Take TerraGoat, pick 5-10 misconfigurations, define the `Tag`/`ConstraintId`/`interpretConstraint` for that subset, and show that the correct config type-checks while the TerraGoat version doesn't.

## Bottom Line

The core architecture (Arrow + SheetDiagram + ScopeState + erasure) transfers without structural change. The work is in (a) richer resource types with attributes/references, (b) domain-specific constraint formalization (CIDR, ports, IAM), and (c) state import from Terraform. The mathematical bones are the same.
