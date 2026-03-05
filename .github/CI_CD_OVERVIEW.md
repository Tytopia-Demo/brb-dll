# CI/CD Overview

This document provides an overview of all continuous integration and deployment pipelines configured for this repository.

## Active CI/CD Systems

### 1. GitHub Actions

**Status**: ✓ Active and Optimized

**Location**: `.github/workflows/`

**Purpose**: Security scanning and dependency auditing

**Workflows**:
- `frogbot.yml` - JFrog Frogbot security scanning

**Optimization Status**:
- All workflows optimized for runner efficiency
- Resource monitoring instrumented
- Job timeouts configured
- See `.github/RUNNER_GUIDELINES.md` for details

### 2. CircleCI

**Status**: ✓ Active

**Location**: `.circleci/config.yml`

**Purpose**: Test suite execution

**Configuration**:
- Ruby version: 2.6.3
- Dependencies: Redis 4.0.12
- Test framework: RSpec

**Note**: CircleCI configuration uses separate billing and resource allocation. For CircleCI optimization guidance, see [CircleCI Resource Classes documentation](https://circleci.com/docs/configuration-reference/#resourceclass).

## CI/CD Strategy

### Division of Responsibilities

| System | Responsibility | Frequency |
|--------|---------------|-----------|
| **GitHub Actions** | Security scanning (Frogbot) | Daily + PR events |
| **CircleCI** | Test suite execution | On commits |

### Why Multiple Systems?

This repository uses both GitHub Actions and CircleCI:
- **GitHub Actions**: Integrated with GitHub for security workflows and dependency scanning
- **CircleCI**: May have existing test infrastructure or specific requirements

### Consolidation Considerations

If considering CI/CD consolidation, evaluate:

1. **Migration to GitHub Actions Only**
   - Pros: Single CI/CD platform, unified billing, easier maintenance
   - Cons: Migration effort, potential workflow changes
   - Recommendation: Migrate CircleCI tests to GitHub Actions if no special requirements exist

2. **Keep Both Systems**
   - Pros: Separation of concerns, platform redundancy
   - Cons: Two systems to maintain, duplicate configuration overhead
   - Recommendation: Only if CircleCI provides specific features or historical reasons exist

## Cost Optimization

### GitHub Actions
- **Optimizations Applied**: Runner sizing, timeouts, resource monitoring
- **Estimated Savings**: 20-30% reduction in runner minutes through proper sizing and timeouts
- **Monitoring**: Resource logs available in workflow runs

### CircleCI
- **Current State**: Using default Docker executors
- **Potential Optimizations**:
  - Review resource class sizing
  - Enable caching for dependencies
  - Optimize Docker image layers
  - Consider parallelism for test suites

## Recommended Next Steps

### Short Term (This Quarter)
1. ✅ Optimize GitHub Actions workflows (COMPLETED)
2. ⏳ Monitor resource usage from GitHub Actions logs
3. ⏳ Document CircleCI test suite performance baseline

### Medium Term (Next Quarter)
1. ⏳ Evaluate CircleCI resource class optimization
2. ⏳ Consider test suite parallelization
3. ⏳ Assess feasibility of CI/CD consolidation

### Long Term (This Year)
1. ⏳ Consider full migration to single CI/CD platform
2. ⏳ Implement advanced caching strategies
3. ⏳ Automate performance regression detection

## Performance Baselines

### GitHub Actions (Frogbot Security Scan)
- Expected duration: 3-8 minutes
- Timeout: 15 minutes
- Runner: ubuntu-latest (2-core, 7GB RAM)
- Typical resource usage: <1GB memory, low CPU

### CircleCI (Test Suite)
- Expected duration: TBD (to be measured)
- Ruby version: 2.6.3
- Dependencies: Redis
- Test framework: RSpec

*Note: Establish performance baselines by monitoring next 10 runs*

## Monitoring Dashboard

Track these metrics across both platforms:

| Metric | GitHub Actions | CircleCI |
|--------|---------------|----------|
| Average run time | Monitor logs | CircleCI dashboard |
| Success rate | Actions tab | CircleCI dashboard |
| Resource usage | Workflow logs | CircleCI insights |
| Cost per month | Billing page | CircleCI billing |

## Troubleshooting

### GitHub Actions Issues
- Check workflow run logs in Actions tab
- Verify secrets are configured correctly
- Review timeout settings if jobs are cancelled
- See resource monitoring output for bottlenecks

### CircleCI Issues
- Check CircleCI dashboard for detailed logs
- Verify environment variables are set
- Review Docker container health
- Check Redis connectivity

## Contact & Support

For questions about:
- **GitHub Actions optimization**: See `.github/RUNNER_GUIDELINES.md`
- **Workflow changes**: Open PR with proposed changes
- **CI/CD strategy**: Open discussion in repository

---

*Last Updated: March 2024*
