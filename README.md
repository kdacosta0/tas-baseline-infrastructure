# TAS Baseline Infrastructure

This repository contains the infrastructure code for deploying a standardized Trusted Artifact Signer (TAS) baseline environment on OpenShift. The infrastructure is designed to be easily deployable and configurable for performance testing and monitoring.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Components](#components)
- [Quick Start](#quick-start)
- [Available `make` Commands](#available-make-commands)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [License](#license)

## Overview

The TAS Baseline Infrastructure provides a complete setup for:
- Trusted Artifact Signer (TAS) components
- Monitoring and observability stack
- Performance testing capabilities
- Standardized resource configurations

## Prerequisites

- OpenShift cluster access
- `oc` CLI tool installed
- Ansible installed
- Python 3.x

## Components

The infrastructure includes the following main components:

1. **Core TAS Components**:
   - Fulcio (Certificate Authority)
   - Rekor (Transparency Log)
   - Trillian (Backend Database)
   - CTLog (Certificate Transparency Log)
   - TSA (Timestamp Authority)
   - TUF (The Update Framework)

2. **Monitoring Stack**:
   - Grafana for visualization
   - Prometheus integration
   - Custom dashboards for TAS performance KPIs

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/kdacosta0/tas-baseline-infrastructure.git
   cd tas-baseline-infrastructure
   ```

2. Configure OIDC, in the [baseline-config.yml](baseline-config.yml) file:
   ```bash
   oidc:
      issuer_url: "https://your-oidc-issuer-url"
      client_id: "your_client_id"
      type: "your_type"
   ```

3. Deploy the infrastructure:
   ```bash
   make deploy
   ```

## Available Make Commands

- `make deploy` - Deploy TAS baseline infrastructure
- `make clean` - Remove ALL TAS resources and operators
- `make clean-apps` - Remove only TAS applications (keep operators)
- `make check` - Verify prerequisites
- `make status` - Show deployment status

## Configuration

The infrastructure can be configured through `baseline-config.yml`. Key configuration areas include:

- OIDC settings (required)
- Certificate configurations
- Resource limits and requests
- Component enablement
- Monitoring settings
- Storage configurations

## Monitoring

The infrastructure includes a comprehensive monitoring setup with Grafana dashboards that provide real-time insights into TAS performance and health metrics.

### Dashboard Overview

![TAS Performance Dashboard](images/grafana-dashboard.png)
*Figure 1: TAS Performance Dashboard showing key metrics and system health indicators*

The monitoring stack includes:
- Grafana dashboards for performance KPIs
- Prometheus integration
- Custom metrics collection
- Resource utilization tracking

## License

This project is licensed under the terms included in the [LICENSE](LICENSE) file.
