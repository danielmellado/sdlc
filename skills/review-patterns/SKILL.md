# Review Patterns for Go/OpenShift Projects

You are performing a code review focused on common patterns and anti-patterns
found in Go projects, particularly in the OpenShift/Kubernetes ecosystem.

## Trigger

This skill is triggered by: `/review-patterns` (reviews current diff) or
`/review-patterns <ref>` (reviews a specific git ref)

## Instructions

### Step 1: Get the Diff

If no ref is provided, review the working tree changes:
```bash
git diff
```

Otherwise, review the specified ref:
```bash
git diff <ref>
```

### Step 2: Apply Review Patterns

Check the diff against each of the following patterns. Only report findings
that are actually present -- do not report patterns that don't apply.

#### Error Handling

- **Swallowed errors**: `err` assigned but not checked or returned
- **Bare error wrapping**: `fmt.Errorf("failed: %v", err)` instead of
  `fmt.Errorf("doing X: %w", err)` (use `%w` for wrapping)
- **Error string style**: Error strings should not be capitalized or end with
  punctuation (Go convention)
- **Missing error context**: Errors returned without adding context about what
  operation failed

#### Naming and Structure

- **Exported names without docs**: Exported functions/types/constants missing
  godoc comments
- **Stutter**: `package.PackageThing` naming (e.g., `config.ConfigManager`)
- **Interface bloat**: Interfaces with >5 methods that could be split
- **God functions**: Functions >80 lines that should be decomposed
- **Unexported test helpers**: Test helper functions that should use `t.Helper()`

#### Concurrency

- **Unbuffered channels in goroutines**: Potential deadlocks
- **Missing context propagation**: Functions that take `context.Context` but
  don't pass it to callees
- **Goroutine leaks**: Goroutines started without clear shutdown path
- **Shared state without sync**: Struct fields accessed from multiple
  goroutines without mutex or atomic

#### Kubernetes/OpenShift Specific

- **Hardcoded namespaces**: Using literal namespace strings instead of
  configuration
- **Missing RBAC markers**: Controller functions without `// +kubebuilder:rbac`
  annotations
- **Deep-copy omission**: Modifying objects from the cache without `DeepCopy()`
- **Status vs Spec updates**: Mixing status and spec updates in the same
  reconcile pass
- **Missing finalizers**: Resources with external dependencies that need cleanup
  but lack finalizer logic
- **Watch predicates**: Controllers watching resources without filtering
  predicates, causing unnecessary reconciliation

#### Testing

- **Table tests without subtests**: Table-driven tests not using `t.Run()`
- **Test assertions without messages**: `assert.Equal(t, a, b)` without
  a descriptive message
- **Brittle assertions**: Tests that depend on exact error strings or ordering
  that may change
- **Missing edge cases**: Happy path tested but error paths, empty inputs,
  and boundary conditions missing

### Step 3: Report Findings

For each finding, report:

```
**[severity]** file:line - pattern name
> brief description of the issue
> suggested fix (one-liner or code snippet)
```

Severities:
- `[must-fix]` - Bug, security issue, or will break in production
- `[should-fix]` - Code quality issue that will cause maintenance pain
- `[nit]` - Style or convention issue, low priority
- `[question]` - Something that looks intentional but warrants confirmation

### Step 4: Summary

End with a summary:

```
## Review Summary
- must-fix: N
- should-fix: N
- nit: N
- question: N

Overall: <one sentence assessment of the change quality>
```

## Notes

- Focus on the diff, not pre-existing code (unless the diff makes existing
  issues worse).
- Be specific: include file names and line numbers.
- When suggesting a fix, show the actual code, not just a description.
- If using with diffity (`/diffity-review`), these patterns will be applied
  as inline comments in the diff viewer.
