```yaml
- name: do-foo
  kind: command
  triggers: { always: true }
  sections: [overview, procedure, output]
  fallback: stub-from-section
```
