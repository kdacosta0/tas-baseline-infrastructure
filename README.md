# RHTAS Performance Analysis Infrastructure

This repository contains a comprehensive suite of tools for deploying and conducting performance analysis on the Red Hat Trusted Artifact Signer (RHTAS) stack. The primary goal is to provide a standardized, automated, and repeatable method for benchmarking system performance under various workloads.

The key deliverable of this project is a detailed **[Performance Analysis Report](analysis.md)**, which establishes clear performance metrics, identifies system bottlenecks, and provides data-driven recommendations.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [How to Use (Quick Start)](#how-to-use-quick-start)
- [Available `make` Commands](#available-make-commands)
- [Configuration Profiles](#configuration-profiles)
- [Performance Report & Data](#performance-report--data)
- [License](#license)

## Overview

This infrastructure provides a complete, automated setup for:
- Deploying RHTAS components in different configurations.
- Running various performance test scenarios (`sign`, `verify`).
- Collecting performance metrics (RPS, Latency, CPU/Memory).
- Analyzing results to provide clear, actionable recommendations.

## Prerequisites

- OpenShift cluster access (`oc` CLI tool installed and logged in).
- Ansible and required Python dependencies (the `deploy.sh` script will set up a virtual environment automatically).

## How to Use (Quick Start)

#### Step 1: Deploy the Infrastructure
Choose one of the two available configuration profiles to deploy.
```
    # Deploy the baseline configuration
    make deploy-baseline

    # OR

    # Deploy the optimized configuration (with high resources & affinity)
    make deploy-optimized
```

#### Step 2: Run a Performance Test
Execute one of the predefined test scenarios. For example, to run the `signing` test with a realistic production load:
```
    # Run the signing test with 100 Virtual Users
    make sign-optimal-range
```

#### Step 3: Clean Up
After testing is complete, remove the deployed resources.

```
    # Remove only the test jobs and RHTAS applications
    make clean-apps

    # OR

    # WARNING: This removes everything, including operators
    make clean
```

## Available `make` Commands

#### Infrastructure Management
- `deploy` or `deploy-baseline`: Deploys the baseline RHTAS configuration.
- `deploy-optimized`: Deploys the high-performance, optimized RHTAS configuration.
- `clean-apps`: Deletes the `Securesign` CR and test-related namespaces.
- `clean`: Deletes everything, including operators, CRDs, and all related namespaces.

#### Performance Tests
A variety of pre-configured tests are available for both `sign` and `verify` workloads.

* **Signing Tests:**
    * `make sign-smoke`: A simple 1 VU, 1 iteration test.
    * `make sign-load`: A light load test with 20 VUs.
    * `make sign-optimal-range`: A realistic production load test with 100 VUs.
    * `make sign-stress`: A high-load stress test.
    * `make sign-fill`: A utility to pre-seed the database with 10,000 entries.

* **Verifying Tests:**
    * `make generate-verify-data`: Generates a UUID needed for verification tests.
    * `make verify-smoke`: A simple 1 VU, 1 iteration test.
    * `make verify-load`: A light load test with 80 VUs.
    * `make verify-optimal-range`: A realistic production load test with 100 VUs.
    * `make verify-stress`: A high-load stress test.

#### Utility Commands
- `check`: Verifies that all prerequisites are met.
- `status`: Shows the deployment status of key RHTAS components.

## Configuration Profiles

This suite uses two primary configurations to compare performance:

1.  **Baseline Configuration (`deploy-baseline`)**
    This profile uses a single replica for all services, with high `resources` allocated only to the `trillian-db` component and no specific `affinity` rules. It serves as a benchmark for "out-of-the-box" performance.

2.  **Optimized Configuration (`deploy-optimized`)**
    This profile is designed for high performance. It uses robust `resources` for all key components and applies `nodeAffinity` rules to strategically co-locate services, minimizing network latency and resource contention.

## Performance Report & Data

The main output of this project is the comprehensive analysis report, which contains all methodologies, results, and recommendations.

- Report: [Performance Analysis Report (analysis.md)](analysis.md)**

All raw data (CSV files exported from Grafana) from the benchmark runs are archived in the `/results` directory for full transparency and reproducibility.

## License

This project is licensed under the terms included in the [LICENSE](LICENSE) file.
