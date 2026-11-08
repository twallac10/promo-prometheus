test_prometheus_minimal() {
  kinds=$(render dev | yq 'select(.kind=="Deployment" or .kind=="StatefulSet" or .kind=="DaemonSet") | .kind + "/" + .metadata.name' | grep -v -- '---' | tr '\n' ' ')
  [ "$kinds" = "Deployment/prometheus-server " ] || fail "workloads: $kinds"
  [ "$(render dev | yq 'select(.kind=="PersistentVolumeClaim") | .metadata.name' | grep -vc -- '---' || true)" = 0 ] || fail "PVC rendered"
}

test_canary_scrape_job_is_promotable() {
  for t in $TIERS; do
    yq 'select(.kind=="HelmRelease") | .spec.values.prometheus.extraScrapeConfigs' "$ROOT/tiers/$t/release.yaml" |
      grep -q 'podinfo.canary.svc:9898' || fail "$t: canary scrape job not in release.yaml"
  done
  render dev | yq 'select(.kind=="ConfigMap" and .metadata.name=="prometheus-server") | .data."prometheus.yml"' |
    yq -e '.scrape_configs[] | select(.job_name=="canary-podinfo")' >/dev/null || fail "canary job not rendered"
}

test_promtool_config() {
  d=$(mktemp -d)
  cm=$(render dev | yq -o json 'select(.kind=="ConfigMap" and .metadata.name=="prometheus-server") | .data')
  for k in $(echo "$cm" | jq -r 'keys[]'); do echo "$cm" | jq -r --arg k "$k" '.[$k]' > "$d/$k"; done
  img=$(render dev | yq 'select(.kind=="Deployment") | .spec.template.spec.containers[] | select(.name=="prometheus-server") | .image')
  # The chart points rule files at /etc/config; mount the ConfigMap there.
  chmod -R a+rX "$d" # containers run as non-root; mktemp -d is 0700 on Linux
  docker run --rm -v "$d:/etc/config:ro" --entrypoint promtool "$img" check config /etc/config/prometheus.yml
}

test_prometheus_tests() {
  hooks=$(render dev | test_hooks | yq 'select(.kind=="Pod") | .metadata.name' | grep -v -- '---' | sort | tr '\n' ' ')
  [ "$hooks" = "prometheus-test-canary-up prometheus-test-ready " ] || fail "test pods: $hooks"
}
