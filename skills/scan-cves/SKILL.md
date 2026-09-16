# Scan Container Images for CVEs

You are scanning a container image for known CVEs (Common Vulnerabilities and
Exposures). Two scanning backends are supported:

1. **Quay/Clair** (default): skopeo + Quay security API. Best for Quay-hosted images.
2. **ACS/roxctl**: Red Hat Advanced Cluster Security scanner. Works with any
   registry. This is the Konflux-standard backend (migration from clair-scan
   to roxctl-scan).

## Trigger

This skill is triggered by:
- `/scan-cves <IMAGE>` — scan using Quay/Clair (default)
- `/scan-cves <IMAGE> --roxctl` — scan using ACS/roxctl
- `/scan-cves <IMAGE> --correlate` — split CVEs into base image vs application
- `/scan-cves <IMAGE> --correlate --severity high` — correlate, filtered by severity

IMAGE is a full image reference (e.g. `quay.io/openshift/ose-cli:v4.16`).

## Prerequisites

Verify these tools are available before proceeding:

```bash
# Always needed
command -v jq || echo "ERROR: jq not installed (dnf install jq)"

# For Quay/Clair backend (default)
command -v skopeo || echo "ERROR: skopeo not installed (dnf install skopeo)"
command -v curl || echo "ERROR: curl not installed"

# For ACS/roxctl backend (--roxctl flag)
command -v roxctl || echo "WARNING: roxctl not installed (needed for --roxctl)"
echo "ROX_ENDPOINT=${ROX_ENDPOINT:-NOT SET}"
echo "ROX_API_TOKEN=${ROX_API_TOKEN:+set}"
```

## Instructions

### Step 1: Parse the Image Reference

Extract the components from the image reference:

```
quay.io/<namespace>/<repository>:<tag>
```

If the image is not on `quay.io`, warn that this skill is designed for Quay
images. Other registries may have different security APIs.

### Step 2: Get the Manifest Digest

Use skopeo to inspect the image and extract the digest:

```bash
skopeo inspect docker://<IMAGE> | jq -r '.Digest'
```

For private images, ensure auth is configured:

```bash
# If QUAY_TOKEN is set, use it
if [[ -n "${QUAY_TOKEN:-}" ]]; then
    skopeo inspect --creds='$oauthtoken':$QUAY_TOKEN docker://<IMAGE> | jq -r '.Digest'
fi
```

Also extract the Red Hat component label (useful for cross-referencing):

```bash
skopeo inspect docker://<IMAGE> | jq -r '.Labels["com.redhat.component"] // empty'
```

### Step 3: Check for Multi-Arch Images

If the image is a manifest list (multi-arch), list the child manifests:

```bash
skopeo inspect --raw docker://<IMAGE> | jq '.manifests[]? | {digest: .digest, platform: "\(.platform.os)/\(.platform.architecture)"}'
```

If it is multi-arch, scan each architecture's manifest separately. Focus on
`linux/amd64` first, then report others if they differ.

### Step 4: Query Quay Security API

Fetch the vulnerability report for the manifest:

```bash
NAMESPACE="<namespace>"
REPO="<repository>"
DIGEST="<digest_from_step_2>"

# For public images:
curl -s -H "Accept: application/json" \
    "https://quay.io/api/v1/repository/${NAMESPACE}/${REPO}/manifest/${DIGEST}/security?vulnerabilities=true"

# For private images (requires QUAY_TOKEN):
curl -s -H "Accept: application/json" \
    -H "Authorization: Bearer ${QUAY_TOKEN}" \
    "https://quay.io/api/v1/repository/${NAMESPACE}/${REPO}/manifest/${DIGEST}/security?vulnerabilities=true"
```

### Step 5: Handle Scan Status

Check the `status` field in the response:

- `scanned` — results are ready, proceed to Step 6
- `queued` — scan is pending; wait 30 seconds and retry (up to 3 times)
- `unsupported` — image cannot be scanned (report this to the user)
- `failed` — scan failed (report error details)

```bash
STATUS=$(echo "$RESPONSE" | jq -r '.status')
if [[ "$STATUS" != "scanned" ]]; then
    echo "Scan status: $STATUS (not yet ready, retrying...)"
    sleep 30
    # retry the curl
fi
```

### Step 6: Extract and Classify CVEs

Parse the vulnerability data from the response:

```bash
# Extract all CVEs grouped by severity
echo "$RESPONSE" | jq -r '
    [.data.Layer.Features[] |
     {package: .Name, version: .Version, vulns: [.Vulnerabilities[]? |
       {name: .Name, severity: .Severity, fixed_by: .FixedBy, link: .Link}
     ]} | select(.vulns | length > 0)] |
    sort_by(.vulns[0].severity) | reverse'
```

Group by severity:
- **Critical** — immediate action required
- **High** — should be addressed in next release
- **Medium** — schedule for remediation
- **Low** / **Negligible** — track but low priority
- **Unknown** — review manually

## ACS/roxctl Backend

If the user specified `--roxctl`, skip Steps 2-6 above and use this path instead.

### Step R1: Validate ACS Configuration

```bash
if [[ -z "${ROX_ENDPOINT:-}" ]]; then
    echo "ERROR: ROX_ENDPOINT not set. Export it: export ROX_ENDPOINT=central.stackrox.svc:443"
    exit 1
fi
if [[ -z "${ROX_API_TOKEN:-}" ]]; then
    echo "ERROR: ROX_API_TOKEN not set. Generate one in the ACS console under Platform Configuration > Integrations > API Token."
    exit 1
fi
```

### Step R2: Scan with roxctl

```bash
roxctl image scan \
    --image="<IMAGE>" \
    --endpoint="$ROX_ENDPOINT" \
    --force \
    --output json
```

Add `--include-snoozed` if the user wants to see snoozed/deferred CVEs.
Add `--cluster=<name>` if scanning from a cluster-local registry.

If the scan fails with TLS errors, suggest `--insecure-skip-tls-verify` or
check that `ROX_ENDPOINT` is correct.

### Step R3: Parse roxctl Output

The `--output json` format returns a summary with vulnerability counts by
severity. The severity enum uses ACS naming:

| ACS Severity | Common Name |
|-------------|-------------|
| `CRITICAL_VULNERABILITY_SEVERITY` | Critical |
| `IMPORTANT_VULNERABILITY_SEVERITY` | High |
| `MODERATE_VULNERABILITY_SEVERITY` | Medium |
| `LOW_VULNERABILITY_SEVERITY` | Low |

Extract CVEs:

```bash
echo "$RESPONSE" | jq -r '
    [.result.vulnerabilities[]? |
     {cve: .cve, component: (.componentName // .component),
      version: (.componentVersion // .version),
      fixed_by: (.componentFixedVersion // "no fix"),
      severity: (.severity | gsub("_VULNERABILITY_SEVERITY";"") | gsub("IMPORTANT";"HIGH") | gsub("MODERATE";"MEDIUM"))}
    ] | sort_by(
        if .severity == "CRITICAL" then 0
        elif .severity == "HIGH" then 1
        elif .severity == "MEDIUM" then 2
        else 3 end
    )'
```

### Step R4: Check Policy Violations (Optional)

For Konflux pipelines, also run a policy check:

```bash
roxctl image check \
    --image="<IMAGE>" \
    --endpoint="$ROX_ENDPOINT" \
    --output json
```

This returns any build-time policy violations (beyond just CVEs). Report
any `FAIL_BUILD_ENFORCEMENT` policies that would block the image in a
Konflux pipeline.

---

### Step 7: Cross-Reference with Red Hat Security Data (Optional)

If the image has a `com.redhat.component` label (Red Hat builder/base images),
cross-reference with the Red Hat Security Data API for additional context:

```bash
COMPONENT="<com.redhat.component_label>"

# Get CVEs affecting this component
curl -s "https://access.redhat.com/hydra/rest/securitydata/cve.json?package=${COMPONENT}&after=$(date -d '-90 days' +%Y-%m-%d)" | jq '.[].CVE'
```

This provides:
- Official Red Hat severity ratings (may differ from Clair/NVD)
- RHSA/RHBA advisory links with fix details
- Affected product/version matrix

### Step 8: Report

Present findings in this format:

```
## CVE Scan: <IMAGE>

### Summary
| Severity | Count |
|----------|-------|
| Critical | N     |
| High     | N     |
| Medium   | N     |
| Low      | N     |
| Total    | N     |

**Backend**: <Quay/Clair or ACS/roxctl>
**Scan date**: <timestamp>
**Digest**: <manifest_digest>
**Red Hat component**: <component_label or "N/A">

### Critical / High CVEs (Action Required)
| CVE | Package | Current Version | Fixed In | Severity | Link |
|-----|---------|----------------|----------|----------|------|
| ... | ...     | ...            | ...      | ...      | ...  |

### Medium CVEs
| CVE | Package | Current Version | Fixed In | Severity | Link |
|-----|---------|----------------|----------|----------|------|
| ... | ...     | ...            | ...      | ...      | ...  |

### Low / Negligible CVEs
<collapsed summary or count only>

### Recommendations
1. <specific remediation steps>
2. <whether a newer base image version fixes the critical/high CVEs>
3. <if using a Red Hat image, link to the relevant RHSA advisory>

### Unfixed CVEs
<list any CVEs without a FixedBy version — these need upstream fixes>
```

### Step 8b: Base Image Correlation (--correlate)

When `--correlate` or `--diff-base` is passed, split CVEs into two buckets:

1. **Base image CVEs** (RPM / OS packages): identified by version strings
   containing `.el7`, `.el8`, `.el9`, `.fc*`, or `module+`. These come from
   the base image layer (e.g. `ubi8-micro`, `ubi9-minimal`).
2. **Application CVEs** (Go modules, npm, Python, etc.): everything else.
   These are introduced by the application build.

The correlation report should show:
- Each bucket's CVE table (severity, CVE ID, package, version, fixed_in)
- Per-bucket severity counts
- A summary line: "Base image: N CVEs, Application: M CVEs, Total: N+M"
- If application CVEs are zero, highlight that rebasing would fix everything

This is particularly useful for Red Hat operator images, which are typically a
statically-linked Go binary on top of `ubi-micro`. In practice, all RPM CVEs
come from the base image and the operator introduces none.

Example usage:
```bash
scan-cves quay.io/rhobs/observability-operator:latest --correlate
scan-cves quay.io/rhobs/observability-operator:latest --correlate --severity high
```

## Notes

- For Red Hat builder images (`ubi8`, `ubi9`, `ose-*`), always check if a newer
  tag exists that includes the fixes: `skopeo list-tags docker://quay.io/<image>`
- The Quay security scanner (Clair) may not have data for very new images.
  If status is `queued`, suggest the user retry in a few minutes.
- Multi-arch images: report the `linux/amd64` results by default, note if
  other architectures have different vulnerability counts.
- For images NOT on Quay, suggest using `--roxctl` (ACS backend) or
  alternative scanners: `trivy`, `grype`, or `podman image scan`.
- Always include the raw CVE count even when the list is long — maintainers
  need the full picture for compliance reporting.
- **Konflux migration note**: Konflux is migrating from `clair-scan` to
  `roxctl-scan` (ACS) as the default image scanning task. If the user is
  working in a Konflux pipeline context, recommend using the `--roxctl`
  backend. The roxctl-scan task uses the same `roxctl image scan` command
  under the hood. See the Konflux docs on applying task migrations for
  pipeline YAML updates.
