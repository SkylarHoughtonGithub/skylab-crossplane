# Skylab Platform Rework — skylab-crossplane

Oct 12, 2026 · @Skylar

> One slice of a five-repo rework. See the **Cross-repo map** below for siblings.

## North star

Skylab becomes four public platform repos on GitHub plus a tenant repo in Gitea, built in a fixed order, with one owner per layer. It runs as a homelab hub managing spoke clusters on AWS and GCP. The old argo-\*, backstage-\* and shoutsky-images repos are archived once their contents have a new home. There is no live infrastructure to migrate, so every repo is built clean.

Humans and agents only ever write to Git; Argo CD is the single path into the clusters, and AWS foundations come from Terraform CI.

### Layer ownership

| Layer | Tool | Owns | Never touches |
| --- | --- | --- | --- |
| Delivery | Argo CD | Applying Git state to clusters; deciding which cluster gets what | Resources rendered by KubeVela |
| Infrastructure API | Crossplane | Cloud resources: EKS, networking, buckets, databases | Helm releases and app workloads |
| Application API | KubeVela | App components, traits, delivery workflow, the resources it renders | Cluster placement |
| Front door | Backstage | Catalog, templates, MCP actions for AI clients | Direct writes to clusters |
| Investigation | HolmesGPT | Read-only root-cause analysis of alerts | Any change to the system |
| Remediation | tack-ai | Proposing fixes as pull requests, behind policy and approval | Direct cluster changes |

### Cross-repo map

| Repo | Host | Replaces | Purpose |
| --- | --- | --- | --- |
| skylab-gitops | GitHub | skylab-argo-root, skylab-argo-bootstrap, skylab-argo-workloads | Everything Argo CD syncs: platform charts, cluster config, workloads |
| skylab-terraform | GitHub | proxmox-qdevice from shoutsky-images | AWS and GCP foundations: OIDC, workload identity, buckets, IAM, qdevice |
| skylab-backstage | GitHub | skylab-backstage-catalog, Backstage image from shoutsky-images | Backstage app, image, chart, templates, plugins |
| **skylab-crossplane** (this repo) | GitHub | crossplane-xrd folder in skylab-argo-bootstrap | Cloud-agnostic XRDs with AWS and GCP compositions, as an OCI package |
| platform/tenants | Gitea | skylab-backstage-configs | Scaffolder output: KubeVela Applications and infra requests |
| tack-ai | GitHub (existing) | n/a | Governed remediation agent; integration work only |

### Build order

1. **skylab-gitops**, including Gitea, KubeVela and the observability stack. Everything else plugs into it.
2. **skylab-terraform**, moved up because Loki, Tempo and TechDocs need buckets and Roles Anywhere before they can store anything.
3. **skylab-backstage**, including the Gitea pull-request action and MCP actions.
4. **skylab-crossplane**, with EKS and GKE behind one cluster API, handing new clusters to Argo CD.
5. **Archive the old repos** once each piece has moved.
6. **Golden paths**: KubeVela definitions and the templates that use them.
7. **AI layer**: model gateway, HolmesGPT, tack-ai remediation, kagent.
8. **Portfolio finish**: profile README, pins, ADRs.

## Status (as of 2026-10-19)

Progress through the shared build order:

- [x] 1. **skylab-gitops** — bootstrap, skylab-apps renderer, CI pipeline, waves -2 → 6 landed (wave 2 deferred pending this repo's OCI package). 16 Applications healthy in dev; Backstage running in degraded-mode guest sign-in.
- [x] 2. **skylab-terraform** — substantively complete. Seven stacks and five modules with fmt/validate/tflint/trivy CI. Follow-ups below.
- [x] 3. **skylab-backstage** — image + chart + plugins shipped; wrapper chart deployed by gitops wave 6.
- [ ] 4. **skylab-crossplane** — scaffolding + first API landed. `crossplane.yaml` Configuration metadata with pinned provider/function dependencies, Bucket XRD (v2, Namespaced) with a single composition using `function-go-templating` to render S3 or GCS based on `spec.cloud`, example XRs for both clouds, and a CI pipeline running `crossplane beta validate` + `beta render` with expected-output diff. Release workflow in progress: on tag `v*.*.*` CI runs `crossplane xpkg build` + push to `ghcr.io/skylarhoughtongithub/skylab-platform`. After `v0.1.0` publishes, the gitops wave 2 Application pin lands as a one-line follow-up.
- [ ] 5. Archive the old repos
- [ ] 6. Golden paths
- [ ] 7. AI layer (includes tack-ai)
- [ ] 8. Portfolio finish

### Deferred wiring in skylab-gitops (now unblocked)

Terraform's `stacks/roles-anywhere` is live, so these can land next:

- cert-manager ClusterIssuers (`StepClusterIssuer` + ACME Let's Encrypt)
- trust-manager Bundle distributing the step-ca root
- external-secrets ClusterSecretStores (AWS Secrets Manager, GCP Secret Manager)
- step-ca provisioner secrets via ExternalSecret

### Deferred follow-ups in skylab-terraform

- Tighten scaffold policies: ESO `SecretsManagerReadWrite`, `terraform-ci` role `AdministratorAccess`, GCP SAs on `roles/owner`/`roles/editor`.
- Port the actual qdevice container logic from `shoutsky-images/images/proxmox-qdevice`.
- qdevice image build+push CI.
- Retire `terraform/development/` legacy content once nothing references it.

### Deferred CI work in skylab-gitops

- OCI push to GHCR on main
- Rendered-diff PR comment on PRs

---

## This repo

The XRDs and compositions become a versioned Crossplane Configuration package pushed to GHCR as OCI, and skylab-gitops installs a pinned version at wave 2. Crossplane provisions infrastructure only; it never deploys Helm releases.

```
skylab-crossplane/
├── crossplane.yaml   # Configuration metadata and dependencies
├── apis/
│   ├── network/
│   ├── ekscluster/
│   ├── eksaccess/
│   ├── clusterrbac/
│   ├── postgres/     # consumed by a KubeVela component
│   └── bucket/
├── functions/        # pinned composition functions
├── examples/
└── tests/
```

### Design decisions

- **Crossplane v2:** namespaced XRs and pipeline-mode compositions with functions. v2 has no claims; the KubeVela component that renders an XR acts as the developer-facing request.
- **Cluster handoff to Argo CD:** every cluster composition (EKS or GKE) also creates an Argo CD cluster Secret on the hub through provider-kubernetes, carrying env labels and `awsAuthConfig`. The cluster-generator ApplicationSet picks it up and rolls the platform out in wave order. Deleting the XR removes the Secret.
- **App-facing APIs:** `postgres` and `bucket` XRDs exist so KubeVela components can request infrastructure without developers seeing Crossplane.

### Cloud-agnostic APIs

| API | AWS composition | GCP composition |
| --- | --- | --- |
| KubernetesCluster | EKS, VPC, access entries | GKE, VPC, Workload Identity |
| Network | VPC, subnets, NAT gateway | VPC, subnets, Cloud NAT |
| Bucket | S3 | Cloud Storage |
| Postgres | RDS | Cloud SQL |

- A single `cloud` parameter selects the composition; no provider-specific fields reach the developer.
- Install the Upbound AWS and GCP provider families with only the sub-providers needed, to keep CRD count and memory down.
- Every cluster composition creates the Argo CD cluster Secret on the hub: `awsAuthConfig` for EKS, the `argocd-k8s-auth gcp` exec provider for GKE.

### Cross-cloud design decisions

| Decision | Options | Lean |
| --- | --- | --- |
| GKE mode | Autopilot, Standard zonal | Standard zonal, since Autopilot restricts privileged DaemonSets |
| Composition selection | Composition labels, a selection function | Function, so selection logic is testable with `crossplane beta render` |

### CI

- `crossplane beta render` against every example, compared with expected output.
- `crossplane beta validate` against the XRD schemas.
- Chainsaw end-to-end tests as a stretch goal.
- `crossplane xpkg build` and push to GHCR on tagged releases.

### Done when

- [ ] A Backstage template creates an EKS or GKE cluster that Argo CD adopts with no manual step
- [ ] A KubeVela app requesting Postgres gets a database through an XR
- [ ] Package versions are promoted by PR in skylab-gitops

---

## Open decisions

| Decision | Options | Lean | Decide by |
| --- | --- | --- | --- |
| Crossplane version | v1 with claims, v2 | v2, since there is nothing to migrate | Start of this repo |

## Upstream and downstream

- **skylab-terraform** provides the IAM for provider-aws (the `crossplane/` stack) and the GCP service accounts for provider-gcp.
- **skylab-gitops** wave 1 installs Crossplane and providers; wave 2 pins and installs this Configuration package. The cluster-generator ApplicationSet in gitops consumes the cluster Secrets this repo creates.
- **skylab-backstage** cluster and database templates reference these XRDs by name and version.
