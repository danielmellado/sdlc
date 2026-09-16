#!/usr/bin/env bash
# Shell aliases and functions for AI SDLC workflow.
# Source this from your .bashrc:
#   source ~/Devel/openshift/sdlc/shell/ai-aliases.sh

SDLC_ROOT="${SDLC_ROOT:-$HOME/Devel/openshift/sdlc}"

# --- Sandboxed Claude Code ---
alias nono-claude="$SDLC_ROOT/nono/scripts/nono-claude.sh"
alias claudio="nono-claude"

# --- Model shortcuts (sandboxed) ---
alias claude-opus="nono-claude --model opus"
alias claude-sonnet="nono-claude --model sonnet"
alias claude-haiku="nono-claude --model haiku"

# --- Sandboxed OpenCode ---
alias nono-opencode="$SDLC_ROOT/nono/scripts/nono-opencode.sh"
alias oc-ai="nono-opencode"

# --- Local LLM via OpenCode + Ollama ---
alias ai-local="nono-opencode --local"

# --- Diffity shortcuts ---
alias dr="diffity"
alias drr="diffity --review"

# --- Quick speckit ---
alias spec-init="specify init . --ai claude"

# --- tmux-ai: open a tmux session with nvim + AI agent side by side ---
# Usage:
#   tmux-ai                         # current dir, Claude Code (default)
#   tmux-ai ~/project               # specific dir
#   tmux-ai ~/project opus          # specific dir + model
#   tmux-ai . sonnet                # current dir + model
#   tmux-ai ~/project --opencode    # use OpenCode instead of Claude Code
#   tmux-ai ~/project --oc          # short form
#   tmux-ai ~/project --local       # OpenCode + Ollama (local LLM)
tmux-ai() {
    local project_dir="${1:-.}"
    local model="${2:-}"
    local agents="${3:-1}"
    local use_opencode=false
    local use_local=false

    # Parse flags from any positional argument
    local new_args=()
    for arg in "$@"; do
        case "$arg" in
            --opencode|--oc) use_opencode=true ;;
            --local)         use_opencode=true; use_local=true ;;
            *)               new_args+=("$arg") ;;
        esac
    done
    project_dir="${new_args[0]:-.}"
    model="${new_args[1]:-}"
    agents="${new_args[2]:-1}"

    project_dir="$(cd "$project_dir" && pwd)"
    local session_name
    session_name="ai-$(basename "$project_dir")"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux attach-session -t "$session_name"
        return
    fi

    local agent_cmd
    if [[ "$use_opencode" == true ]]; then
        agent_cmd="$SDLC_ROOT/nono/scripts/nono-opencode.sh"
        if [[ "$use_local" == true ]]; then
            agent_cmd="$agent_cmd --local"
        fi
    else
        agent_cmd="$SDLC_ROOT/nono/scripts/nono-claude.sh"
        if [[ -n "$model" ]]; then
            agent_cmd="$agent_cmd --model $model"
        fi
    fi

    # Auto-install diffity commands if not already present
    if [[ ! -d "$project_dir/.claude/commands" ]] || ! ls "$project_dir/.claude/commands"/diffity-* &>/dev/null; then
        echo "Installing diffity commands in $project_dir..."
        (cd "$project_dir" && _sdlc_install_diffity_commands) || true
    fi

    # Set up shared coordination file for multi-agent sessions
    if [[ "$agents" -ge 2 ]]; then
        mkdir -p "$project_dir/.claude"
        cat > "$project_dir/.claude/team-status.md" <<'TEAMEOF'
# Agent Team Status

Shared coordination file. Each agent should:
1. Read this file at the start of every task
2. Update their section when starting/finishing work
3. Check for conflicts before modifying shared files
4. Note any blockers or handoffs needed

## Agent Roles
- **Agent 1 (top-right)**: Coder — implementation, core logic
- **Agent 2 (middle-right)**: Reviewer — review Agent 1's changes, catch issues, suggest improvements
- **Agent 3 (bottom-right)**: QE — write tests, verify behavior, check edge cases

## Current Tasks
| Agent | Status | Working on |
|-------|--------|------------|
| 1     | idle   |            |
| 2     | idle   |            |
| 3     | idle   |            |

## Coordination Notes
<!-- Agents: write notes here about shared state, conflicts, or handoffs -->

TEAMEOF

        # Add team instructions to CLAUDE.md if not already present
        if [[ ! -f "$project_dir/CLAUDE.md" ]]; then
            cat > "$project_dir/CLAUDE.md" <<'CLAUDEEOF'
# Project Instructions

## Multi-Agent Coordination

You are part of a team of agents working on this project simultaneously.
Read `.claude/team-status.md` before starting any task, and update it with
your current status. Check for conflicts before editing files another agent
may be working on.

If you see another agent is working on a file you need, note it in the
Coordination Notes section and work on something else until they're done.
CLAUDEEOF
        elif ! grep -qF "team-status.md" "$project_dir/CLAUDE.md" 2>/dev/null; then
            cat >> "$project_dir/CLAUDE.md" <<'CLAUDEEOF'

## Multi-Agent Coordination

You are part of a team of agents working on this project simultaneously.
Read `.claude/team-status.md` before starting any task, and update it with
your current status. Check for conflicts before editing files another agent
may be working on.

If you see another agent is working on a file you need, note it in the
Coordination Notes section and work on something else until they're done.
CLAUDEEOF
        fi
    fi

    local pane_cmd="$agent_cmd; echo 'Agent exited. Press enter to close.'; read"

    tmux new-session -d -s "$session_name" -c "$project_dir" "nvim ."
    tmux split-window -h -t "$session_name" -l 40% -c "$project_dir" "$pane_cmd"

    # Use actual pane IDs (robust regardless of base-index settings)
    local first_agent_pane
    first_agent_pane="$(tmux list-panes -t "$session_name" -F '#{pane_id}' | tail -1)"

    if [[ "$agents" -ge 2 ]]; then
        tmux split-window -v -t "$first_agent_pane" -c "$project_dir" "$pane_cmd"
    fi
    if [[ "$agents" -ge 3 ]]; then
        tmux split-window -v -t "$first_agent_pane" -c "$project_dir" "$pane_cmd"
    fi

    local nvim_pane
    nvim_pane="$(tmux list-panes -t "$session_name" -F '#{pane_id}' | head -1)"
    tmux select-pane -t "$nvim_pane"
    tmux attach-session -t "$session_name"
}

# Multi-agent shortcuts
#   tmux-ai2 .                # nvim + 2 agents (coder + reviewer)
#   tmux-ai3 .                # nvim + 3 agents (coder + reviewer + QE)
#   tmux-ai3 . opus           # same with specific model
#   tmux-ai2 . --opencode     # 2 OpenCode agents
#   tmux-ai3 . --local        # 3 agents with local LLM
tmux-ai2() {
    local flags=()
    local positional=()
    for arg in "$@"; do
        case "$arg" in
            --opencode|--oc|--local) flags+=("$arg") ;;
            *) positional+=("$arg") ;;
        esac
    done
    tmux-ai "${positional[0]:-.}" "${positional[1]:-}" 2 "${flags[@]}"
}
tmux-ai3() {
    local flags=()
    local positional=()
    for arg in "$@"; do
        case "$arg" in
            --opencode|--oc|--local) flags+=("$arg") ;;
            *) positional+=("$arg") ;;
        esac
    done
    tmux-ai "${positional[0]:-.}" "${positional[1]:-}" 3 "${flags[@]}"
}

# --- Quick CI triage ---
ci-triage() {
    local pr_number="$1"
    if [[ -z "$pr_number" ]]; then
        echo "Usage: ci-triage <PR_NUMBER>"
        return 1
    fi
    npx gh-ci-artifacts "$pr_number"
}

# --- CVE scanning for container images ---
# Supports two backends:
#   1. Quay/Clair (default): skopeo + Quay security API
#   2. ACS/roxctl: roxctl image scan (Konflux migration from clair-scan)
#
# Usage:
#   scan-cves quay.io/openshift/ose-cli:v4.16
#   scan-cves quay.io/openshift/ose-cli:v4.16 --severity high
#   scan-cves quay.io/openshift/ose-cli:v4.16 --roxctl
#   scan-cves quay.io/openshift/ose-cli:v4.16 --correlate
#   scan-cves registry.redhat.io/ubi9:latest --roxctl
scan-cves() {
    local image=""
    local severity_filter=""
    local use_roxctl=false
    local correlate=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --roxctl|--acs)       use_roxctl=true ;;
            --severity)           shift; severity_filter="$1" ;;
            --correlate|--diff-base) correlate=true ;;
            -*)                   echo "Unknown flag: $1"; return 1 ;;
            *)                    image="$1" ;;
        esac
        shift
    done

    if [[ -z "$image" ]]; then
        echo "Usage: scan-cves <IMAGE> [--severity critical|high|medium|low] [--roxctl] [--correlate]"
        echo ""
        echo "Backends:"
        echo "  (default)  Quay/Clair via skopeo + Quay API"
        echo "  --roxctl   ACS via roxctl image scan (requires ROX_ENDPOINT + ROX_API_TOKEN)"
        echo ""
        echo "Options:"
        echo "  --correlate   Separate CVEs from the base image (RPMs) vs application code"
        echo "  --severity    Filter results by severity level"
        echo ""
        echo "Examples:"
        echo "  scan-cves quay.io/openshift/ose-cli:v4.16"
        echo "  scan-cves quay.io/openshift/ose-cli:v4.16 --severity high"
        echo "  scan-cves quay.io/openshift/ose-cli:v4.16 --roxctl"
        echo "  scan-cves quay.io/rhobs/observability-operator:latest --correlate"
        return 1
    fi

    if [[ "$use_roxctl" == true ]]; then
        _scan_cves_roxctl "$image" "$severity_filter" "$correlate"
    else
        _scan_cves_quay "$image" "$severity_filter" "$correlate"
    fi
}

# Backend: ACS / roxctl image scan
_scan_cves_roxctl() {
    local image="$1"
    local severity_filter="$2"
    local correlate="${3:-false}"

    if ! command -v roxctl &>/dev/null; then
        echo "Error: roxctl is not installed."
        echo "Install: https://mirror.openshift.com/pub/rhacs/assets/latest/bin/Linux/"
        echo "  or:    https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/"
        return 1
    fi

    if [[ -z "${ROX_ENDPOINT:-}" ]]; then
        echo "Error: ROX_ENDPOINT is not set."
        echo "  export ROX_ENDPOINT=central.stackrox.svc:443"
        return 1
    fi
    if [[ -z "${ROX_API_TOKEN:-}" ]]; then
        echo "Error: ROX_API_TOKEN is not set."
        echo "  export ROX_API_TOKEN=<your-acs-api-token>"
        return 1
    fi

    echo "Scanning $image via ACS/roxctl ..."
    echo "Endpoint: $ROX_ENDPOINT"
    echo ""

    local response
    response="$(roxctl image scan \
        --image="$image" \
        --endpoint="$ROX_ENDPOINT" \
        --force \
        --output json \
        2>/dev/null)"

    if [[ $? -ne 0 || -z "$response" ]]; then
        echo "Error: roxctl image scan failed. Check ROX_ENDPOINT and ROX_API_TOKEN."
        return 1
    fi

    # Severity filter for jq
    local sev_jq=""
    if [[ -n "$severity_filter" ]]; then
        local sev_upper
        sev_upper="$(echo "$severity_filter" | tr '[:lower:]' '[:upper:]')"
        case "$sev_upper" in
            CRITICAL) sev_upper="CRITICAL_VULNERABILITY_SEVERITY" ;;
            HIGH)     sev_upper="IMPORTANT_VULNERABILITY_SEVERITY" ;;
            MEDIUM)   sev_upper="MODERATE_VULNERABILITY_SEVERITY" ;;
            LOW)      sev_upper="LOW_VULNERABILITY_SEVERITY" ;;
        esac
        sev_jq="| select(.severity == \"${sev_upper}\")"
    fi

    # Normalize severity names helper (used in jq expressions)
    local norm_sev='gsub("_VULNERABILITY_SEVERITY";"") | gsub("IMPORTANT";"HIGH") | gsub("MODERATE";"MEDIUM")'

    if [[ "$correlate" == true ]]; then
        _scan_cves_roxctl_correlate "$image" "$response" "$sev_jq" "$norm_sev"
    else
        _scan_cves_roxctl_plain "$image" "$response" "$sev_jq" "$norm_sev"
    fi
}

# Plain roxctl output
_scan_cves_roxctl_plain() {
    local image="$1" response="$2" sev_jq="$3" norm_sev="$4"

    echo "=== CVE Summary: $image (ACS/roxctl) ==="
    echo ""
    echo "$response" | jq -r "
        .result.vulnerabilities // [] |
        group_by(.severity) | map({severity: .[0].severity, count: length}) |
        sort_by(
            if .severity == \"CRITICAL_VULNERABILITY_SEVERITY\" then 0
            elif .severity == \"IMPORTANT_VULNERABILITY_SEVERITY\" then 1
            elif .severity == \"MODERATE_VULNERABILITY_SEVERITY\" then 2
            elif .severity == \"LOW_VULNERABILITY_SEVERITY\" then 3
            else 4 end
        ) | .[] |
        \"\(.severity | ${norm_sev}): \(.count)\""

    local total
    total="$(echo "$response" | jq '[.result.vulnerabilities // [] | .[]] | length')"
    echo "---"
    echo "Total: $total"
    echo ""
    echo "=== CVE Details ==="
    echo ""
    echo "$response" | jq -r "
        [.result.vulnerabilities // [] | .[] ${sev_jq}] |
        sort_by(
            if .severity == \"CRITICAL_VULNERABILITY_SEVERITY\" then 0
            elif .severity == \"IMPORTANT_VULNERABILITY_SEVERITY\" then 1
            elif .severity == \"MODERATE_VULNERABILITY_SEVERITY\" then 2
            elif .severity == \"LOW_VULNERABILITY_SEVERITY\" then 3
            else 4 end
        ) | .[] |
        \"\(.severity | ${norm_sev})\t\(.cve)\t\(.componentName // .component)\t\(.componentVersion // .version)\t\(.componentFixedVersion // \"no fix\")\"" \
        | column -t -s $'\t' -N "SEVERITY,CVE,PACKAGE,VERSION,FIXED_IN" 2>/dev/null || cat
}

# Correlation for roxctl: RPM source = base image, language packages = app
_scan_cves_roxctl_correlate() {
    local image="$1" response="$2" sev_jq="$3" norm_sev="$4"

    echo ""
    echo "============================================================"
    echo "  CVE CORRELATION: $image (ACS/roxctl)"
    echo "============================================================"

    # roxctl uses componentSource: OS_COMPONENT vs LANGUAGE_COMPONENT
    # or we detect by source type. Fall back to version heuristic.
    echo ""
    echo "=== BASE IMAGE CVEs (OS packages) ==="
    echo ""

    local base_data
    base_data="$(echo "$response" | jq -r "
        [.result.vulnerabilities // [] | .[]
         | select(.source == \"OS\" or (.componentVersion // .version | test(\"\\\\.(el[7-9]|fc[0-9]|module\\\\+)\")))
         ${sev_jq}] |
        sort_by(
            if .severity == \"CRITICAL_VULNERABILITY_SEVERITY\" then 0
            elif .severity == \"IMPORTANT_VULNERABILITY_SEVERITY\" then 1
            elif .severity == \"MODERATE_VULNERABILITY_SEVERITY\" then 2
            elif .severity == \"LOW_VULNERABILITY_SEVERITY\" then 3
            else 4 end
        ) | .[] |
        \"\(.severity | ${norm_sev})\t\(.cve)\t\(.componentName // .component)\t\(.componentVersion // .version)\t\(.componentFixedVersion // \"no fix\")\"
    ")"

    if [[ -n "$base_data" ]]; then
        printf "%-10s %-18s %-30s %-25s %s\n" "SEVERITY" "CVE" "PACKAGE" "VERSION" "FIXED_IN"
        printf "%-10s %-18s %-30s %-25s %s\n" "--------" "---" "-------" "-------" "--------"
        echo "$base_data" | while IFS=$'\t' read -r sev cve pkg ver fix; do
            printf "%-10s %-18s %-30s %-25s %s\n" "$sev" "$cve" "$pkg" "$ver" "$fix"
        done
    else
        echo "  (none)"
    fi

    local base_total
    base_total="$(echo "$response" | jq "[.result.vulnerabilities // [] | .[]
        | select(.source == \"OS\" or (.componentVersion // .version | test(\"\\\\.(el[7-9]|fc[0-9]|module\\\\+)\")))] | length")"

    echo ""
    echo "=== APPLICATION CVEs (language packages) ==="
    echo ""

    local app_data
    app_data="$(echo "$response" | jq -r "
        [.result.vulnerabilities // [] | .[]
         | select((.source == \"OS\" or (.componentVersion // .version | test(\"\\\\.(el[7-9]|fc[0-9]|module\\\\+)\"))) | not)
         ${sev_jq}] |
        sort_by(
            if .severity == \"CRITICAL_VULNERABILITY_SEVERITY\" then 0
            elif .severity == \"IMPORTANT_VULNERABILITY_SEVERITY\" then 1
            elif .severity == \"MODERATE_VULNERABILITY_SEVERITY\" then 2
            elif .severity == \"LOW_VULNERABILITY_SEVERITY\" then 3
            else 4 end
        ) | .[] |
        \"\(.severity | ${norm_sev})\t\(.cve)\t\(.componentName // .component)\t\(.componentVersion // .version)\t\(.componentFixedVersion // \"no fix\")\"
    ")"

    if [[ -n "$app_data" ]]; then
        printf "%-10s %-18s %-50s %-20s %s\n" "SEVERITY" "CVE" "MODULE" "VERSION" "FIXED_IN"
        printf "%-10s %-18s %-50s %-20s %s\n" "--------" "---" "------" "-------" "--------"
        echo "$app_data" | while IFS=$'\t' read -r sev cve pkg ver fix; do
            printf "%-10s %-18s %-50s %-20s %s\n" "$sev" "$cve" "$pkg" "$ver" "$fix"
        done
    else
        echo "  ✅ No CVEs from application code"
    fi

    local app_total
    app_total="$(echo "$response" | jq "[.result.vulnerabilities // [] | .[]
        | select((.source == \"OS\" or (.componentVersion // .version | test(\"\\\\.(el[7-9]|fc[0-9]|module\\\\+)\"))) | not)] | length")"

    echo ""
    echo "============================================================"
    printf "  %-35s %s\n" "Base image (OS packages):" "$base_total CVEs"
    printf "  %-35s %s\n" "Application (language packages):" "$app_total CVEs"
    printf "  %-35s %s\n" "Total:" "$(( base_total + app_total )) CVEs"
    echo "============================================================"

    if [[ "$app_total" -eq 0 && "$base_total" -gt 0 ]]; then
        echo ""
        echo "  ✅ ALL $base_total CVEs originate from the base image."
        echo "     Rebasing to a patched base would resolve all of them."
    fi
}

# Backend: Quay / Clair via skopeo + Quay API
_scan_cves_quay() {
    local image="$1"
    local severity_filter="$2"
    local correlate="${3:-false}"

    for cmd in skopeo jq curl; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: $cmd is required but not installed."
            return 1
        fi
    done

    # Extract registry, namespace, repo, tag
    local registry namespace repo tag
    registry="$(echo "$image" | cut -d/ -f1)"
    local path_and_tag
    path_and_tag="$(echo "$image" | cut -d/ -f2-)"
    namespace="$(echo "$path_and_tag" | cut -d/ -f1)"
    local repo_tag
    repo_tag="$(echo "$path_and_tag" | cut -d/ -f2-)"
    repo="$(echo "$repo_tag" | cut -d: -f1)"
    tag="$(echo "$repo_tag" | grep -oP ':\K.*' || echo 'latest')"

    if [[ "$registry" != *"quay"* ]]; then
        echo "Warning: Quay backend is optimized for Quay.io images."
        echo "For other registries, try: scan-cves $image --roxctl"
        echo "  or: trivy image $image"
        echo ""
    fi

    echo "Inspecting $image ..."

    # Get digest via skopeo
    local creds_args=()
    if [[ -n "${QUAY_TOKEN:-}" ]]; then
        creds_args=("--creds=\$oauthtoken:${QUAY_TOKEN}")
    fi

    # Check if this is a manifest list (multi-arch) and resolve to amd64 child
    local raw_manifest
    raw_manifest="$(skopeo inspect --raw "${creds_args[@]}" "docker://${image}" 2>/dev/null)"
    local digest=""
    local is_multiarch=false

    if echo "$raw_manifest" | jq -e '.manifests' &>/dev/null; then
        is_multiarch=true
        digest="$(echo "$raw_manifest" | jq -r '[.manifests[] | select(.platform.architecture == "amd64" and .platform.os == "linux")] | .[0].digest')"
        if [[ -z "$digest" || "$digest" == "null" ]]; then
            digest="$(echo "$raw_manifest" | jq -r '.manifests[0].digest')"
        fi
        echo "Multi-arch image detected, using linux/amd64 child manifest"
    fi

    # Fall back to regular inspect if not multi-arch or no child found
    if [[ -z "$digest" || "$digest" == "null" ]]; then
        digest="$(skopeo inspect "${creds_args[@]}" "docker://${image}" 2>/dev/null | jq -r '.Digest')"
    fi

    if [[ -z "$digest" || "$digest" == "null" ]]; then
        echo "Error: Could not get manifest digest for $image"
        return 1
    fi
    echo "Digest: $digest"

    # Get Red Hat component label
    local component
    component="$(skopeo inspect "${creds_args[@]}" "docker://${image}" 2>/dev/null | jq -r '.Labels["com.redhat.component"] // empty')"
    if [[ -n "$component" ]]; then
        echo "Red Hat component: $component"
    fi

    # Query Quay security API
    local api_url="https://${registry}/api/v1/repository/${namespace}/${repo}/manifest/${digest}/security?vulnerabilities=true"
    local auth_header=""
    if [[ -n "${QUAY_TOKEN:-}" ]]; then
        auth_header="-H 'Authorization: Bearer ${QUAY_TOKEN}'"
    fi
    local response
    response="$(curl -s -H "Accept: application/json" ${auth_header} "$api_url")"

    local status
    status="$(echo "$response" | jq -r '.status')"
    if [[ "$status" == "queued" ]]; then
        echo "Scan queued, waiting 30s..."
        sleep 30
        response="$(curl -s -H "Accept: application/json" ${auth_header} "$api_url")"
        status="$(echo "$response" | jq -r '.status')"
    fi

    if [[ "$status" != "scanned" ]]; then
        echo "Scan status: $status"
        echo "The image may not have been scanned yet. Try again in a few minutes."
        return 1
    fi

    # Severity filter for jq
    local severity_jq_filter=""
    if [[ -n "$severity_filter" ]]; then
        severity_filter="$(echo "$severity_filter" | sed 's/./\U&/')"
        severity_jq_filter="| select(.severity == \"${severity_filter}\")"
    fi

    if [[ "$correlate" == true ]]; then
        _scan_cves_quay_correlate "$image" "$response" "$severity_jq_filter" "$component"
    else
        _scan_cves_quay_plain "$image" "$response" "$severity_jq_filter"
    fi
}

# Plain CVE output (no correlation)
_scan_cves_quay_plain() {
    local image="$1"
    local response="$2"
    local severity_jq_filter="$3"

    echo ""
    echo "=== CVE Summary: $image (Quay/Clair) ==="
    echo ""
    echo "$response" | jq -r '
        [.data.Layer.Features[].Vulnerabilities[]? | .Severity] |
        group_by(.) | map({severity: .[0], count: length}) |
        sort_by(
            if .severity == "Critical" then 0
            elif .severity == "High" then 1
            elif .severity == "Medium" then 2
            elif .severity == "Low" then 3
            elif .severity == "Negligible" then 4
            else 5 end
        ) | .[] | "\(.severity): \(.count)"'

    local total
    total="$(echo "$response" | jq '[.data.Layer.Features[].Vulnerabilities[]?] | length')"
    echo "---"
    echo "Total: $total"
    echo ""

    echo "=== CVE Details ==="
    echo ""
    echo "$response" | jq -r "
        [.data.Layer.Features[] |
         {package: .Name, version: .Version, vulns: [.Vulnerabilities[]? |
           {name: .Name, severity: .Severity, fixed_by: (.FixedBy // \"no fix\"), link: .Link}
         ]} | select(.vulns | length > 0) | .vulns[] as \$v |
         {cve: \$v.name, package: .package, version: .version, fixed_by: \$v.fixed_by, severity: \$v.severity, link: \$v.link}
         ${severity_jq_filter}] |
        sort_by(
            if .severity == \"Critical\" then 0
            elif .severity == \"High\" then 1
            elif .severity == \"Medium\" then 2
            elif .severity == \"Low\" then 3
            else 4 end
        ) | .[] |
        \"\(.severity)\t\(.cve)\t\(.package)\t\(.version)\t\(.fixed_by)\""  | column -t -s $'\t' -N "SEVERITY,CVE,PACKAGE,VERSION,FIXED_IN" 2>/dev/null || cat
}

# Correlation: split CVEs into base image (RPMs) vs application code
_scan_cves_quay_correlate() {
    local image="$1"
    local response="$2"
    local severity_jq_filter="$3"
    local component="${4:-unknown}"

    # Detect base image from Clair features (ubi entries) or component label
    local base_image_name=""
    base_image_name="$(echo "$response" | jq -r '
        [.data.Layer.Features[]? | select(.Name | test("^ubi[0-9]")) | .Name] | first // empty')"
    if [[ -z "$base_image_name" ]]; then
        base_image_name="$component"
    fi

    echo ""
    echo "============================================================"
    echo "  CVE CORRELATION: $image"
    echo "  Base image: ${base_image_name:-unknown}"
    echo "============================================================"

    # RPM packages: version contains .el{7,8,9} or known RHEL version patterns
    local rpm_filter='select(.Version | test("\\.(el[7-9]|fc[0-9]|module\\+)") )'
    local app_filter='select(.Version | test("\\.(el[7-9]|fc[0-9]|module\\+)") | not)'

    # --- Base image section ---
    echo ""
    echo "=== BASE IMAGE CVEs (RPM packages) ==="
    echo ""

    local base_cve_data
    base_cve_data="$(echo "$response" | jq -r "
        [.data.Layer.Features[]
         | ${rpm_filter}
         | {package: .Name, version: .Version, vulns: [.Vulnerabilities[]?
             | {name: .Name, severity: .Severity, fixed_by: (.FixedBy // \"no fix\")}
           ]} | select(.vulns | length > 0) | .vulns[] as \$v |
         {severity: \$v.severity, cve: \$v.name, package: .package, version: .version, fixed_by: \$v.fixed_by}
         ${severity_jq_filter}]
        | sort_by(
            if .severity == \"Critical\" then 0
            elif .severity == \"High\" then 1
            elif .severity == \"Medium\" then 2
            elif .severity == \"Low\" then 3
            else 4 end)
        | .[] | \"\(.severity)\t\(.cve)\t\(.package)\t\(.version)\t\(.fixed_by)\"
    ")"

    if [[ -n "$base_cve_data" ]]; then
        printf "%-10s %-18s %-30s %-25s %s\n" "SEVERITY" "CVE" "PACKAGE" "VERSION" "FIXED_IN"
        printf "%-10s %-18s %-30s %-25s %s\n" "--------" "---" "-------" "-------" "--------"
        echo "$base_cve_data" | while IFS=$'\t' read -r sev cve pkg ver fix; do
            printf "%-10s %-18s %-30s %-25s %s\n" "$sev" "$cve" "$pkg" "$ver" "$fix"
        done
    else
        echo "  (none)"
    fi

    # Base severity counts
    local base_counts
    base_counts="$(echo "$response" | jq -r "
        [.data.Layer.Features[] | ${rpm_filter}
         | .Vulnerabilities[]? | .Severity]
        | group_by(.) | map({(.[0]): length}) | add // {}")"
    local base_total
    base_total="$(echo "$response" | jq "[.data.Layer.Features[] | ${rpm_filter} | .Vulnerabilities[]?] | length")"

    echo ""
    echo "  Base image totals: $(echo "$base_counts" | jq -r 'to_entries | map("\(.key): \(.value)") | join(", ")')"

    # --- Application section ---
    echo ""
    echo "=== APPLICATION CVEs (Go modules / non-RPM) ==="
    echo ""

    local app_cve_data
    app_cve_data="$(echo "$response" | jq -r "
        [.data.Layer.Features[]
         | ${app_filter}
         | {package: .Name, version: .Version, vulns: [.Vulnerabilities[]?
             | {name: .Name, severity: .Severity, fixed_by: (.FixedBy // \"no fix\")}
           ]} | select(.vulns | length > 0) | .vulns[] as \$v |
         {severity: \$v.severity, cve: \$v.name, package: .package, version: .version, fixed_by: \$v.fixed_by}
         ${severity_jq_filter}]
        | sort_by(
            if .severity == \"Critical\" then 0
            elif .severity == \"High\" then 1
            elif .severity == \"Medium\" then 2
            elif .severity == \"Low\" then 3
            else 4 end)
        | .[] | \"\(.severity)\t\(.cve)\t\(.package)\t\(.version)\t\(.fixed_by)\"
    ")"

    if [[ -n "$app_cve_data" ]]; then
        printf "%-10s %-18s %-50s %-20s %s\n" "SEVERITY" "CVE" "MODULE" "VERSION" "FIXED_IN"
        printf "%-10s %-18s %-50s %-20s %s\n" "--------" "---" "------" "-------" "--------"
        echo "$app_cve_data" | while IFS=$'\t' read -r sev cve pkg ver fix; do
            printf "%-10s %-18s %-50s %-20s %s\n" "$sev" "$cve" "$pkg" "$ver" "$fix"
        done
    else
        echo "  ✅ No CVEs from application code"
    fi

    local app_total
    app_total="$(echo "$response" | jq "[.data.Layer.Features[] | ${app_filter} | .Vulnerabilities[]?] | length")"

    # --- Final summary ---
    echo ""
    echo "============================================================"
    printf "  %-35s %s\n" "Base image (RPMs):" "$base_total CVEs"
    printf "  %-35s %s\n" "Application (Go/non-RPM):" "$app_total CVEs"
    printf "  %-35s %s\n" "Total:" "$(( base_total + app_total )) CVEs"
    echo "============================================================"

    if [[ "$app_total" -eq 0 && "$base_total" -gt 0 ]]; then
        echo ""
        echo "  ✅ ALL $base_total CVEs originate from the base image."
        echo "     Rebasing to a patched base would resolve all of them."
    fi
}

# --- Install diffity as Claude Code slash commands ---
_sdlc_install_diffity_commands() {
    local tmpdir
    tmpdir="$(mktemp -d -p "${HOME}")"
    git clone --depth 1 https://github.com/kamranahmedse/diffity.git "$tmpdir" 2>/dev/null || {
        echo "Failed to clone diffity repo"
        rm -rf "$tmpdir"
        return 1
    }
    local skills_dir="$tmpdir/skills"
    if [[ -d "$skills_dir" ]]; then
        mkdir -p .claude/commands
        for skill_dir in "$skills_dir"/diffity-*; do
            local name
            name="$(basename "$skill_dir")"
            [[ -f "$skill_dir/SKILL.md" ]] && cp "$skill_dir/SKILL.md" ".claude/commands/${name}.md"
        done
        echo "Diffity commands installed in .claude/commands/"
    fi
    rm -rf "$tmpdir"
}

# --- Quick project setup with all AI tools ---
ai-init() {
    local project_dir="${1:-.}"
    cd "$project_dir" || return 1
    echo "Setting up AI tools in $(pwd)..."
    specify init . --ai claude 2>/dev/null || echo "speckit already initialized or not installed"
    _sdlc_install_diffity_commands
    echo "Done. Use 'tmux-ai .' to start coding."
}
