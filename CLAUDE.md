# MyToday – Claude Guidelines

## Pull Requests
- **Always create a PR for new features.** Never commit feature work directly to `main`.
- Branch off `main`, make changes, open a PR, and wait for the user to merge.

## Testing (TDD)
Follow a strict red-green workflow for every feature:

1. **Write the tests first** – add test cases that cover the new behaviour.
2. **Run and confirm they fail** – the tests must be red before any implementation.
3. **Implement the feature** – write the minimum code needed to make the tests pass.
4. **Run and confirm they pass** – all new (and existing) tests must be green.

Run the test suite with:
```bash
swift test --package-path /Users/chrfalch/repos/chrfalch/MyToday
```
