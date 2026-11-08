test_retention_per_tier() {
  for t in $TIERS; do
    case $t in dev) want=2h;; stg) want=6h;; prd) want=12h;; esac
    got=$(render "$t" | yq 'select(.kind=="Deployment") | .spec.template.spec.containers[] | select(.name=="prometheus-server") | .args[] | select(test("retention.time"))')
    [ "$got" = "--storage.tsdb.retention.time=$want" ] || fail "$t: $got"
  done
}
