# GitHub Actions Quick Reference

Quick reference guide for common workflow patterns and runner selection in this repository.

## Runner Selection Cheat Sheet

```yaml
# Security scanning, linting, simple checks
runs-on: ubuntu-latest  # 2-core, 7GB RAM
timeout-minutes: 10-15

# Unit tests for small/medium projects
runs-on: ubuntu-latest  # 2-core, 7GB RAM
timeout-minutes: 10-20

# Large test suites with parallelization
runs-on: ubuntu-latest-4-core  # 4-core, 16GB RAM
timeout-minutes: 20-30

# Heavy compilation or builds
runs-on: ubuntu-latest-4-core  # 4-core, 16GB RAM
runs-on: ubuntu-latest-8-core  # 8-core, 32GB RAM (rarely needed)
timeout-minutes: 30-60
```

## Essential Workflow Template

```yaml
name: My Workflow

on:
  push:
    branches: [ master ]
  pull_request:

jobs:
  my-job:
    runs-on: ubuntu-latest  # Choose appropriate runner
    timeout-minutes: 15     # ALWAYS set timeout

    steps:
      # Resource monitoring (recommended)
      - name: Monitor resources (start)
        run: |
          echo "CPU: $(nproc), Memory:"
          free -h

      # Your workflow steps here
      - uses: actions/checkout@v3

      # Resource monitoring (end)
      - name: Monitor resources (end)
        if: always()
        run: free -h
```

## Common Patterns

### Caching Dependencies (Ruby)
```yaml
- uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.1'
    bundler-cache: true  # Automatically caches gems
```

### Matrix Testing
```yaml
strategy:
  matrix:
    ruby-version: [2.7, 3.0, 3.1]
  max-parallel: 3  # Limit concurrent jobs
```

### Conditional Execution
```yaml
- name: Deploy
  if: github.ref == 'refs/heads/master'
  run: ./deploy.sh
```

### Job Dependencies
```yaml
jobs:
  test:
    runs-on: ubuntu-latest

  deploy:
    needs: test  # Runs after test succeeds
    runs-on: ubuntu-latest
```

## Timeout Guidelines

| Job Type | Typical Duration | Recommended Timeout |
|----------|-----------------|---------------------|
| Linting | 1-2 min | 5-10 min |
| Security scan | 3-5 min | 10-15 min |
| Unit tests | 5-10 min | 15-20 min |
| Integration tests | 10-20 min | 30 min |
| Build & deploy | 10-30 min | 45-60 min |

**Rule of thumb**: Set timeout to 2-3x typical duration

## Resource Monitoring Snippets

### Minimal Monitoring
```yaml
- run: echo "CPU: $(nproc)" && free -h
```

### Detailed Monitoring
```yaml
- name: System info
  run: |
    echo "=== System Resources ==="
    echo "CPU: $(nproc)"
    free -h
    df -h
    echo "======================="
```

### With Timestamps
```yaml
- name: Monitor resources
  run: |
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    free -h
```

## Troubleshooting

### Job times out
```yaml
# Increase timeout
timeout-minutes: 30  # Increase from default

# Or optimize the job:
# - Cache dependencies
# - Use larger runner
# - Parallelize tasks
```

### Out of memory
```yaml
# Use larger runner
runs-on: ubuntu-latest-4-core  # 16GB RAM
# or
runs-on: ubuntu-latest-8-core  # 32GB RAM
```

### Slow dependency installation
```yaml
# Use caching
- uses: actions/cache@v3
  with:
    path: vendor/bundle
    key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
```

## Checklist for New Workflows

- [ ] `timeout-minutes` set on all jobs
- [ ] Appropriate runner size selected
- [ ] Resource monitoring included
- [ ] Dependencies cached where applicable
- [ ] Job dependencies defined (if needed)
- [ ] Secrets referenced correctly
- [ ] Tested locally (if possible)
- [ ] YAML syntax validated

## Useful Commands

### Validate YAML syntax
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/my-workflow.yml'))"
```

### Check workflow status
```bash
gh run list --workflow=my-workflow.yml
```

### View workflow logs
```bash
gh run view <run-id> --log
```

## Further Reading

- **Comprehensive Guide**: [RUNNER_GUIDELINES.md](RUNNER_GUIDELINES.md)
- **CI/CD Overview**: [CI_CD_OVERVIEW.md](CI_CD_OVERVIEW.md)
- **GitHub Actions Docs**: https://docs.github.com/en/actions

---

*Quick reference for developers - Last updated: March 2024*
