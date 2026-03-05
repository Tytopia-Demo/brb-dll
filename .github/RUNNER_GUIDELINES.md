# GitHub Actions Runner Selection Guidelines

This document provides guidance on selecting appropriately sized runners for GitHub Actions workflows to optimize costs and efficiency.

## Overview

Proper runner sizing ensures:
- **Cost efficiency**: Avoid paying for unused compute resources
- **Performance**: Match resource requirements to workload characteristics
- **Reliability**: Prevent out-of-memory errors and timeouts

## Available Runner Types

### Standard GitHub-Hosted Runners

| Runner Label | vCPUs | RAM | Storage | Use Cases |
|-------------|-------|-----|---------|-----------|
| `ubuntu-latest` | 2 | 7 GB | 14 GB SSD | Default choice for most workflows |
| `ubuntu-latest-4-core` | 4 | 16 GB | 14 GB SSD | CPU-intensive builds, parallel testing |
| `ubuntu-latest-8-core` | 8 | 32 GB | 14 GB SSD | Heavy compilation, large test suites |
| `ubuntu-latest-16-core` | 16 | 64 GB | 14 GB SSD | Extremely resource-intensive workloads |

*Note: Larger runners incur higher per-minute costs*

## Runner Selection Decision Tree

### 1. Security Scanning & Linting (e.g., Frogbot, CodeQL, ESLint)
- **Recommended**: `ubuntu-latest` (2-core)
- **Characteristics**: I/O bound, minimal CPU/memory needs
- **Timeout**: 10-15 minutes
- **Example**: Frogbot security scans, dependency audits

### 2. Unit Testing (Small/Medium Projects)
- **Recommended**: `ubuntu-latest` (2-core)
- **Characteristics**: Quick test suites (<5 minutes)
- **Timeout**: 10-15 minutes
- **Example**: Ruby gem test suites, small API services

### 3. Unit Testing (Large Projects)
- **Recommended**: `ubuntu-latest-4-core` (4-core)
- **Characteristics**: Large test suites with parallelization
- **Timeout**: 20-30 minutes
- **Example**: Monolith applications, extensive integration tests

### 4. Compilation & Building
- **Light builds**: `ubuntu-latest` (2-core)
  - Simple Ruby/Python/Node projects
  - No heavy asset compilation
  - Timeout: 10-15 minutes

- **Medium builds**: `ubuntu-latest-4-core` (4-core)
  - Projects with asset pipelines
  - Multiple compilation steps
  - Timeout: 20-30 minutes

- **Heavy builds**: `ubuntu-latest-8-core` (8-core)
  - Large C++/Rust/Go projects
  - Docker image builds with multiple layers
  - Timeout: 30-60 minutes

### 5. Deployment & Release
- **Recommended**: `ubuntu-latest` (2-core)
- **Characteristics**: Primarily network I/O
- **Timeout**: 15-30 minutes
- **Example**: Publishing packages, deploying to cloud platforms

## Workflow Optimization Best Practices

### 1. Always Set Timeouts
```yaml
jobs:
  my-job:
    timeout-minutes: 15  # Adjust based on expected duration + buffer
```

**Guidelines**:
- Set timeout to ~2x typical runtime
- Minimum: 5 minutes for simple jobs
- Maximum: 360 minutes (6 hours) - but reconsider workflow design if needed

### 2. Add Resource Monitoring
```yaml
steps:
  - name: Log system resources
    run: |
      echo "CPU cores: $(nproc)"
      echo "Memory:"
      free -h
      echo "Disk:"
      df -h
```

**Benefits**:
- Track actual resource usage
- Identify optimization opportunities
- Detect resource bottlenecks

### 3. Optimize Matrix Strategies
```yaml
strategy:
  matrix:
    ruby-version: [2.7, 3.0, 3.1]
  fail-fast: false
  max-parallel: 3  # Limit concurrent jobs to manage costs
```

**Guidelines**:
- Use matrices only when testing multiple configurations
- Remove single-item matrices (redundant overhead)
- Set `max-parallel` to control costs and runner availability

### 4. Use Job Dependencies Wisely
```yaml
jobs:
  test:
    runs-on: ubuntu-latest

  deploy:
    needs: test  # Only run after test succeeds
    runs-on: ubuntu-latest
```

**Benefits**:
- Avoid wasting runner time on failed prerequisites
- Enable parallel execution of independent jobs
- Clear workflow execution order

### 5. Cache Dependencies
```yaml
- uses: actions/cache@v3
  with:
    path: vendor/bundle
    key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
```

**Benefits**:
- Reduce network I/O
- Faster workflow execution
- Lower runner utilization time

## Runner Selection for This Repository

### Current Workflows

#### Frogbot Security Scan
- **Runner**: `ubuntu-latest` (2-core)
- **Timeout**: 15 minutes
- **Rationale**: Security scanning is I/O bound; 2-core runner is cost-effective and sufficient
- **Resource Usage**: Typically < 1GB memory, minimal CPU
- **Optimization Applied**: Added resource monitoring, timeout, removed redundant matrix

## Monitoring and Continuous Improvement

### Track These Metrics
1. **Execution Time**: Compare across workflow runs
2. **Resource Usage**: CPU, memory, disk from monitoring steps
3. **Success Rate**: Identify timeout-related failures
4. **Cost**: Runner minutes consumed per workflow

### When to Resize Runners

**Upsize if**:
- Jobs frequently timeout
- Memory usage >80% of available
- CPU-bound tasks with high queue times
- Build/test times are bottleneck for development velocity

**Downsize if**:
- CPU usage consistently <50%
- Memory usage consistently <50%
- Most time spent on I/O operations
- Cost reduction is priority and performance is acceptable

### Review Schedule
- **Monthly**: Review runner usage metrics
- **Quarterly**: Analyze cost trends and optimization opportunities
- **On Changes**: Re-evaluate when adding new workflows or major dependency updates

## Examples

### Example 1: Simple Test Workflow
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest  # 2-core sufficient
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'
          bundler-cache: true
      - run: bundle exec rspec
```

### Example 2: Multi-Version Test Matrix
```yaml
name: Test Matrix
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest  # 2-core sufficient for unit tests
    timeout-minutes: 15
    strategy:
      matrix:
        ruby-version: [2.7, 3.0, 3.1]
      max-parallel: 3
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true
      - run: bundle exec rspec
```

### Example 3: Resource-Intensive Build
```yaml
name: Heavy Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest-4-core  # 4-core for parallel compilation
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v3
      - name: Monitor resources (start)
        run: free -h && nproc
      - name: Build with parallel jobs
        run: make -j$(nproc)
      - name: Monitor resources (end)
        if: always()
        run: free -h
```

## Additional Resources

- [GitHub Actions Runner Images](https://github.com/actions/runner-images)
- [GitHub Actions Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions)
- [Workflow Optimization Tips](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

## Questions or Suggestions?

If you have questions about runner selection or suggestions for improving these guidelines, please open an issue or discussion in this repository.

---

*Last Updated: March 2024*
*Document Version: 1.0*
