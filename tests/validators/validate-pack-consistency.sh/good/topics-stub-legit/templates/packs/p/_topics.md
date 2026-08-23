```yaml
- name: data-access
  kind: pattern
  triggers: { always: true }
  sections: [overview, procedure, output]
  fallback: stub-from-sections
```

```yaml
- name: other
  kind: command
  triggers: { always: true }
  fallback: commands/other.md
```
