# GitHub Configuration

This directory contains GitHub Actions workflows and configuration for the brb-dll repository.

## Structure

- **workflows/** - GitHub Actions workflow definitions
- **workflow-templates/** - Reusable workflow templates for common patterns
- **RUNNER_GUIDELINES.md** - Comprehensive guide for selecting appropriate runner sizes

## Current Workflows

### Frogbot Security Scan (`workflows/frogbot.yml`)

**Purpose**: Automated security scanning of dependencies using JFrog Frogbot

**Triggers**:
- Pull requests (opened, synchronized)
- Pushes to master branch
- Daily schedule (midnight UTC)
- Manual dispatch

**Runner**: `ubuntu-latest` (2-core, 7GB RAM)

**Optimizations Applied**:
- ✓ Timeout configured (15 minutes)
- ✓ Resource monitoring instrumented
- ✓ Redundant matrix strategy removed
- ✓ Appropriate runner size selected

**Resource Profile**:
- Typical duration: 3-8 minutes
- CPU usage: Low (I/O bound)
- Memory usage: < 1 GB
- Optimization rationale: Security scanning is network/I/O intensive; 2-core runner is cost-effective

## Workflow Optimization Summary

This repository's workflows have been optimized following GitHub Actions best practices:

1. **Job Timeouts**: All jobs have `timeout-minutes` configured to prevent runaway processes
2. **Runner Sizing**: Runners are sized appropriately for workload characteristics
3. **Resource Monitoring**: Workflows log resource usage for ongoing optimization
4. **Matrix Optimization**: Redundant single-item matrices have been removed
5. **Documentation**: Comprehensive guidelines available in `RUNNER_GUIDELINES.md`

## Adding New Workflows

When creating new workflows:

1. **Start with a template** from `workflow-templates/`
2. **Consult runner guidelines** in `RUNNER_GUIDELINES.md`
3. **Always set** `timeout-minutes` on jobs
4. **Include resource monitoring** steps for new workflow types
5. **Test locally** when possible before committing

## Best Practices Checklist

When adding or modifying workflows, ensure:

- [ ] Job timeout configured (`timeout-minutes`)
- [ ] Appropriate runner selected (see guidelines)
- [ ] Resource monitoring steps included
- [ ] Caching configured for dependencies
- [ ] Job dependencies properly defined
- [ ] Matrix strategies justified (no single-item matrices)
- [ ] Secrets properly referenced
- [ ] Workflow triggers appropriate for use case

## Monitoring and Maintenance

### Review Schedule
- **Weekly**: Check workflow run times and success rates
- **Monthly**: Review resource usage logs and adjust runner sizes
- **Quarterly**: Audit all workflows for optimization opportunities

### Key Metrics to Track
- Average execution time per workflow
- Runner minute consumption
- Workflow success/failure rates
- Timeout occurrences
- Resource usage from monitoring steps

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Runner Images Repository](https://github.com/actions/runner-images)
- [Billing Information](https://docs.github.com/en/billing/managing-billing-for-github-actions)

## Questions?

For questions about workflow configuration or optimization, please:
1. Review `RUNNER_GUIDELINES.md` for detailed guidance
2. Check existing workflows for examples
3. Open an issue for discussion

---

*Last Updated: March 2024*
