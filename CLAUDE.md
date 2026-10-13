# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Cloud-agnostic Crossplane XRDs and compositions, packaged as a versioned OCI Configuration pushed to GHCR. `skylab-gitops` installs a pinned version at wave 2. See `plan.md` for the full rework plan.

Fresh repo — nothing is built yet.

## Layer

**Infrastructure API (Crossplane).** Owns cloud resources: EKS, GKE, VPCs, buckets, databases. Never deploys Helm releases or app workloads.

## Workflow

- `main` is protected: branch and open a PR (self-merge, 0 approvals).
- No `Co-Authored-By` trailers in commit messages.
- CI: `crossplane beta render` on every example (compared against expected output), `crossplane beta validate` against XRDs, `crossplane xpkg build` + push to GHCR on tagged releases.

## Target repo shape

```
crossplane.yaml   # Configuration metadata and dependencies
apis/
  network/
  ekscluster/
  eksaccess/
  clusterrbac/
  postgres/       # consumed by a KubeVela component
  bucket/
functions/        # pinned composition functions
examples/
tests/
```

## Key decisions

**Crossplane v2.** Namespaced XRs and pipeline-mode compositions with functions. No claims — the KubeVela component that renders an XR is the developer-facing request.

**One cloud parameter.** `KubernetesCluster`, `Network`, `Bucket`, `Postgres` each have AWS and GCP compositions; a `cloud` field selects. No provider-specific fields reach the developer.

**Cluster handoff to Argo CD.** Every cluster composition also creates an Argo CD cluster Secret on the hub via provider-kubernetes, carrying env labels and `awsAuthConfig` (EKS) or the `argocd-k8s-auth gcp` exec provider (GKE). Deleting the XR removes the Secret.

**Composition selection via function**, not labels — so logic is testable with `crossplane beta render`.

## Cross-repo map

- `skylab-gitops` — installs Crossplane and providers at wave 1, this package at wave 2; the cluster-generator ApplicationSet consumes the Secrets this repo creates.
- `skylab-terraform` — provides IAM for provider-aws (`crossplane/` stack) and GCP service accounts for provider-gcp.
- `skylab-backstage` — cluster and database templates reference these XRDs by name and version.
