# Listing Copy: HTTP Load Tester

## Metadata
- **Type:** Skill
- **Name:** http-load-tester
- **Display Name:** HTTP Load Tester
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, hey/ab]
- **Icon:** 🔥

## Tagline

Load test any URL or API — measure RPS, latency percentiles, and find breaking points.

## Description

You can't know if your API will handle production traffic by staring at code. You need to hit it with real concurrent connections and measure what happens. But setting up load testing tools, configuring them correctly, and interpreting results takes time you'd rather spend building.

HTTP Load Tester installs industry-standard benchmarking tools (`hey`, `ab`, `wrk`) and runs configurable load tests with a single command. Get requests/sec, p50/p95/p99 latency, error rates, and throughput — formatted as clean reports or JSON for scripting.

**What it does:**
- 🔥 Load test any HTTP endpoint with configurable concurrency
- 📊 Measure RPS, latency percentiles (p50/p95/p99), error rates
- 📈 Gradual ramp-up mode to find your server's breaking point
- 🔄 Compare before/after reports to validate optimizations
- 📝 JSON output for scripting and CI/CD integration
- ⚡ Auto-installs best available tool (hey > ab > wrk)
- 🔐 Supports auth headers, POST bodies, custom methods

Perfect for developers and DevOps engineers who need to validate API performance before shipping, during CI, or after deployments.

## Core Capabilities

1. Concurrent load testing — Hit endpoints with 1-10,000+ connections
2. Latency percentiles — p50, p95, p99 breakdown
3. Ramp-up testing — Gradually increase load to find breaking points
4. POST/PUT support — Test write endpoints with JSON bodies
5. Auth headers — Load test protected endpoints
6. JSON output — Pipe results into monitoring/alerting
7. Report comparison — Before/after optimization validation
8. Auto-install — Detects OS, installs best tool automatically
9. CI/CD ready — Exit codes and JSON for pipeline integration
10. Multi-tool — Works with hey, ab, or wrk

## Installation Time
**2 minutes** — Run install script, start testing
