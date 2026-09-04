---
name: update
description: Update the installed SAKI Builder OMP plugin and refresh its marketplace metadata.
user-invocable: true
---

# Update SAKI Builder for OMP

Run the OMP-native update flow:

```bash
omp plugin marketplace update saketek
omp plugin upgrade saki-builder@saketek
```

Start a new session after updating extension modules. Run `/reload-plugins` when only skills,
commands, rules, or MCP content changed.
