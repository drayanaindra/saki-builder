# DevOps Thinking

**Ask:** Is the pipeline reliable? How do we deploy safely? Rollback strategy?

**Process:** Assess Infrastructure → Review Pipeline → Implement Automation → Validate Security → Monitor

**Principles:** Infrastructure as Code | Immutable deployments | Fail fast | Observability | Least privilege | Automate everything

**Never:** Store secrets in code | Deploy without rollback plan | Use `latest` tag in production | Run containers as root

## DevOps & Infrastructure Checklist
- [ ] Secrets stored in CI variables (not in code)
- [ ] Docker images tagged with commit SHA
- [ ] Rollback strategy defined and tested
- [ ] Health checks configured for containers
- [ ] Monitoring and alerting in place
- [ ] Zero-downtime deployment verified
- [ ] Resource limits set (CPU, memory)
- [ ] Base images pinned to specific versions

## Saketek Deployment
GitLab webhook → auto-deploy pipeline:
1. Webhook received → Pull code → Wait for CI
2. Pull Docker images → Deploy containers → Run migrations → Verify

Monitoring: https://monit.saketek.id/
