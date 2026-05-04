# 0003. ELK for cluster observability (logs + traces), Prometheus for metrics

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Vijay

## Context

The original platform plan called for the Grafana stack (Loki for logs, Tempo for traces) alongside Prometheus. Two facts reshape that:

1. We already operate Elasticsearch + Kibana in the cluster (`k8s-elk/`) and locally on WSL. The team knows ELK well.
2. Loki/Tempo are lighter than Elasticsearch on memory but introduce a new query language and a new ops story.

The cluster runs on Civo k3s with constrained RAM, so duplicating storage backends (Loki + Tempo + Elasticsearch) is expensive without a clear payoff.

## Decision

- **Logs:** Filebeat (DaemonSet) → Logstash (optional) → Elasticsearch → Kibana. Already deployed under `k8s-elk/`.
- **Traces:** Elastic APM Server. Apps export OTLP; APM Server ingests and writes to Elasticsearch. Traces and logs land in one backend, queryable side-by-side in Kibana.
- **Metrics:** Prometheus (already in `k8s-monitoring/`) scrapes ServiceMonitor targets. Grafana fronts Prometheus for dashboards.
- **Telemetry pipeline:** Each service exports via OpenTelemetry Collector (deployment + DaemonSet). The collector fans out: traces → Elastic APM, metrics → Prometheus (remote write), logs → Elasticsearch.

WSL-local Grafana / Prometheus / Kibana / Elasticsearch are kept for local app development. Cluster and laptop are separate environments — we do not ship cluster telemetry to WSL.

## Consequences

- One backend for logs and traces (Elasticsearch) reduces operational surface area.
- Prometheus retention stays at 15 days to start; longer retention can be added later via remote write to a long-term store.
- Elasticsearch is heavier than Loki — we need at least 4 GB RAM allocated to it on the cluster.
- Grafana stack work is deferred. If we later want unified dashboards across logs/metrics/traces, Grafana can read from Elasticsearch and Prometheus both.
- Apps emit OTLP regardless — the collector is the swap point if we ever change backends.

## Alternatives considered

- **Loki + Tempo + Prometheus + Grafana (original plan).** Lighter, but introduces an unfamiliar logging query language and a separate trace store. Rejected because the team already knows ELK.
- **Run only the WSL stack and tunnel from the cluster.** Operational nightmare; rejected (see ADR discussion thread).
- **Skip tracing entirely for now.** Tempting, but distributed tracing pays back its cost the first time a saga misbehaves. Kept in scope via APM Server.
