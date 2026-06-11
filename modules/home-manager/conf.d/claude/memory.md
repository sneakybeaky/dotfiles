# Development Workflow

All code changes must follow a Test-Driven Development (TDD) flow:

1. **Write an acceptance test first.** Before making any implementation change, write a high-level acceptance test that captures the desired behaviour from the outside. This test should fail initially.

2. **Make the failing test visible.** Run the test and confirm it fails with a clear, meaningful error. Ensure the failure message points at the missing or incorrect behaviour — not at a compilation error or unrelated issue. Fix any diagnostic noise so the failure is unambiguous.

3. **Make the smallest change to pass the test.** Write only enough production code to make the acceptance test (and any supporting unit tests) go green. Resist the urge to add logic that isn't yet required by a test.

4. **Refactor.** With the tests passing, clean up the implementation and tests: remove duplication, improve naming, simplify structure. Re-run the tests after each refactor step to confirm nothing regresses.

Repeat the cycle for each new behaviour or bug fix. Never skip straight to implementation — the failing test comes first.

# Go Testing

When writing tests in Go, use the `github.com/google/go-cmp/cmp` package for equality testing instead of `reflect.DeepEqual` or manual comparisons. Use `cmp.Diff` to produce readable diffs on failure, for example:

```go
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("mismatch (-want +got):\n%s", diff)
}
```
