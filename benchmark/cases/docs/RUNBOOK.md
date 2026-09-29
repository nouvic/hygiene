# Runbook

## Rolling back a release

Redeploy the previous tag and confirm that the health check turns green.

## Incident 2026-09-01, degraded metrics

Metrics were missing for nine minutes after the collector restarted. The gap
was in the collector, not in the service. Alerts fired late because the
threshold is measured over a fifteen minute window.
