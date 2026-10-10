# The search cluster moved to the search team's own state (iac/tofu/search-index). Hand-off recorded in
# iac/docs/adr/0012-hand-search-cluster-to-search-state.md; their state imported it on 2026-09-30.
removed {
  from = aws_opensearch_domain.search

  lifecycle {
    destroy = false
  }
}
