---
name: gateway-deploy
description: Route deployment tasks to the right library skill. Detects intent and returns specific platform skill file paths to load.
type: gateway
tier: core
domains: [deploy, ops, infrastructure, devops]
trigger: "deploy, release, publish, ship to production, setup hosting, hosting provider"
user-invocable: false
---

## Purpose

You are the Deployment Gateway. Your job is to detect intent from the current deployment task and return the exact library skill paths that should be loaded. Do NOT execute the deployment — only route to the right knowledge.

## Intent Detection → Skill Routing

Read the task description and match against these patterns:

| Intent Keywords | Load Skill |
|---|---|
| `aws`, `ec2`, `ecs`, `s3`, `cloudfront`, `elastic beanstalk` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/aws/SKILL.md` |
| `gcp`, `google cloud`, `cloud run`, `compute engine`, `app engine` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/gcp/SKILL.md` |
| `cloudflare`, `pages`, `workers`, `wrangler` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/cloudflare/SKILL.md` |
| `vercel`, `next.js hosting` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/vercel/SKILL.md` |
| `netlify` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/netlify/SKILL.md` |
| `railway`, `nixpacks` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/railway/SKILL.md` |
| `coolify`, `self-hosted paas` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/coolify/SKILL.md` |
| `fly`, `fly.io`, `firecracker`, `flyctl` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/fly/SKILL.md` |
| `vps`, `ssh`, `scp`, `rsync`, `baremetal`, `ubuntu`, `debian`, `systemd`, `pm2` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/ssh-vps/SKILL.md` |
| `kubernetes`, `k8s`, `kubectl`, `helm`, `pods`, `deployments` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/kubernetes/SKILL.md` |
| `docker registry`, `dockerhub`, `ghcr`, `ecr`, `push image` | `${CLAUDE_PLUGIN_ROOT}/config/skills/deploy/docker-registry/SKILL.md` |

## Output Format

Return ONLY this — no prose:

```
GATEWAY_DEPLOY:
Domain: deploy
Skills to load:
  - [absolute/path/to/SKILL.md]

Instructions: Read the above skill files before proceeding with your deployment task.
```

If no specific skill matches, return:
```
GATEWAY_DEPLOY:
Domain: deploy
Skills to load: none (proceed with general deployment patterns or use scaffold-deploy to generate configs)
```
