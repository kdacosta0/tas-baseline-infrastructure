# Performance Analysis Report: Red Hat Trusted Artifact Signer (RHTAS)

**Author:** Kristián Da Costa Menezes
**Date:** September 11, 2025
**Version:** 1.0

### **1. Executive Summary**

This report provides a detailed analysis of the performance characteristics of the Red Hat Trusted Artifact Signer (RHTAS) stack. The objectives were to establish performance benchmarks for a baseline and an optimized configuration, define resource requirements for various workloads, and analyze system behavior under load and in failure scenarios.

All tests were conducted on a single-replica ("non-HA") configuration to obtain a clean and comparable performance baseline for a single instance of the service.

**Key Findings:**

* In the baseline "Universal" configuration, the system achieves a stable throughput of approximately **985 requests per second (RPS)** under a realistic mixed workload.
* By applying an **"Optimized Profile,"** which includes robust resource allocation (`resources`) and strategic component placement (`affinity`), the system's performance was significantly improved.
* The Optimized Profile achieved a total throughput of **~1.29K RPS** under the same mixed workload, representing a **performance increase of over 31%** while simultaneously reducing latency.
* The most critical finding is that the horizontal scalability (adding more replicas) of the gRPC services (`trillian-logserver`, `ctlog`) is currently ineffective due to application-level logic in the gRPC client.
* The system demonstrated high resilience by gracefully degrading under CPU pressure and successfully self-healing after memory exhaustion (`OOMKill`).

This report concludes with final recommendations for deploying in production environments that require high performance and stability.

### **2. Test Environment & Methodology**

* **Cluster:** The tests were performed on a dedicated 3-node OpenShift Cluster (OCP 4.19).
* **Node Specification:** 8 vCPU cores per node.
* **RHTAS Version:** The tests were conducted using the RHTAS Operator version 1.3.0.
* **Conditions:** No other significant applications were running in the cluster during the tests.
* **CPU Metrics:** CPU usage values represent the per-second average number of cores, calculated over a 3-minute window using the Prometheus query `rate(container_cpu_usage_seconds_total[3m])`.
* **Data Window:** Mean (average) values for all metrics were calculated exclusively over the **'sustained load' phase** of each test (excluding the initial ramp-up and final ramp-down) to ensure maximum accuracy.
* **Database State:** To ensure fair and comparable results across all benchmarks, every measured test run was performed on a database that was pre-seeded with a standardized dataset of 10,000 entries. The benchmark test was executed immediately after the seeding process was complete.

### **3. Performance Test Results**

#### **3.1. "Universal" Configuration Performance**

*This configuration was tested with `replicas: 1`, with allocated resources for `trillian-db` only, and without any `affinity` rules.*

**3.1.1. Light Load: SIGN Workload (20 VUs)**

* **Average Performance:** 212 RPS / ~250 ms P95 Latency
* **Resource Consumption (1 Replica):**
    | Component | Max CPU (millicores) | Mean CPU (millicores) | Max Memory (MiB) |
    | :--- | :---: | :---: | :---: |
    | `trillian-logserver`| 1674 | 1606 | 44.9 |
    | `trillian-db` | 1597 | 1514 | 631 |
    | `rekor-server` | 601 | 577 | 47.6 |
    | `fulcio-server` | 262 | 249 | 41.0 |
    | `ctlog` | 189 | 179 | 29.5 |
    | `trillian-logsigner`| 133 | 129 | 33.6 |
    | `tsa-server` | 52.0 | 50 | 33.9 |
    | `tuf-server` | 3.26 | 2.99 | 62.0 |

**3.1.2. Production Load: SIGN Workload (100 VUs)**

* **Average Performance:** ~529 RPS / 516 ms P95 Latency
* **Resource Consumption (1 Replica):**
    | Component | Max CPU (millicores) | Mean CPU (millicores) | Max Memory (MiB) |
    | :--- | :---: | :---: | :---: |
    | `trillian-db` | 3654 | 3394 | 856 |
    | `trillian-logserver`| 3034 | 2887 | 58.6 |
    | `rekor-server` | 1107 | 1036 | 61.2 |
    | `fulcio-server` | 648 | 586 | 42.2 |
    | `ctlog` | 461 | 418 | 33.0 |
    | `trillian-logsigner`| 210 | 194 | 34.8 |
    | `tsa-server` | 133 | 120 | 29.5 |
    | `tuf-server` | 3.76 | 3.26 | 49.4 |

**3.1.3. Production Load: VERIFY Workload (50 VUs)**
*It was determined that 50 VUs is the optimal load for the verify workload. Increasing the load to 100 VUs did not yield a significant RPS increase but doubled the latency.*

* **Average Performance:** ~1.26K RPS / ~86 ms P95 Latency
* **Resource Consumption (1 Replica):**
    | Component | Max CPU (millicores) | Mean CPU (millicores) | Max Memory (MiB) |
    | :--- | :---: | :---: | :---: |
    | `trillian-logserver`| 3128 | 3006 | 60.6 |
    | `trillian-db` | 3091 | 2925 | 475 |
    | `rekor-server` | 1944 | 1881 | 59.7 |
    | `tsa-server` | 185 | 178 | 32.8 |
    | `trillian-logsigner`| 41.4 | 40 | 36.2 |
    | `tuf-server` | 3.72 | 3.15 | 62.1 |
    | `ctlog` | 1.09 | 1.01 | 32.8 |
    | `fulcio-server` | 0.48 | 0.43 | 44.9 |

**3.1.4. Production Load: MIXED Workload (20% Sign / 80% Verify)**

* **Average Total Throughput:** ~985 RPS
    * *Sign Throughput (RPS): ~115 req/s*
    * *Verify Throughput (RPS): ~870 req/s*
* **Average Latency:** Sign: ~462 ms / Verify: ~230 ms
* **Resource Consumption (1 Replica):**
    | Component | Max CPU (millicores) | Mean CPU (millicores) | Max Memory (MiB) |
    | :--- | :---: | :---: | :---: |
    | `trillian-logserver`| 3575 | 3378 | 75.5 |
    | `trillian-db` | 3040 | 2895 | 546 |
    | `rekor-server` | 1600 | 1535 | 63.0 |
    | `tsa-server` | 164 | 155 | 34.7 |
    | `fulcio-server` | 153 | 143 | 42.3 |
    | `ctlog` | 112 | 105 | 28.6 |
    | `trillian-logsigner`| 112 | 107 | 36.3 |
    | `tuf-server` | 3.37 | 3.07 | 64.3 |

#### **3.2. "Optimized Profile" Performance**

*This configuration was tested with `replicas: 1`, high `resources` for all key components, and `affinity` rules (co-locating `trillian-db`, `logserver`, and `logsigner`).*

**MIXED Workload (20% Sign / 80% Verify)**

* **Average Total Throughput:** ~1.29K RPS
    * *Sign Throughput (RPS): ~137 req/s*
    * *Verify Throughput (RPS): ~1.16K req/s*
* **Average Latency:** Sign: ~411 ms / Verify: ~174 ms
* **Resource Consumption (1 Replica):**
    | Component | Max CPU (millicores) | Mean CPU (millicores) | Max Memory (MiB) |
    | :--- | :---: | :---: | :---: |
    | `trillian-logserver`| 3850 | 3702 | 88.0 |
    | `trillian-db` | 2868 | 2758 | 613 |
    | `rekor-server` | 2068 | 1986 | 45.7 |
    | `tsa-server` | 169 | 160 | 36.9 |
    | `fulcio-server` | 152 | 143 | 43.6 |
    | `ctlog` | 136 | 130 | 32.1 |
    | `trillian-logsigner`| 85.6 | 83 | 36.1 |
    | `tuf-server` | 2.81 | 2.65 | 23.7 |

#### **3.3. Performance Comparison: Baseline vs. Optimized (Mixed Workload)**

| Test Profile | Average Total RPS | Average Verify Latency (P95) |
| :--- | :---: | :---: |
| Baseline (No `affinity`) | ~985 req/s | ~230 ms |
| **Optimized (With `affinity`)** | **~1.29K req/s** | **~174 ms** |
| **Performance Gain** | **+31.5%** | **-24.3%** |

### **4. System Behavior and Resilience Analysis**

* **CPU Throttling & OOMKill:** Resilience tests were successful. The system gracefully degrades performance under CPU pressure and correctly self-heals via pod restarts after memory exhaustion (`OOMKill`). Database data persistence was also verified.
* **Overload Behavior:** Under extreme load, the system does not crash but begins to return timeout errors (`gRPC DeadlineExceeded`, `HTTP 504`), indicating that the limiting factor is the backend's processing capacity.
* **"Cold Start" Instability:** A higher probability of initial timeout errors was observed immediately after a fresh deployment before system caches could be warmed up.
* **Storage Exhaustion under Prolonged Stress:** In addition to our focused tests, it is important to note a known system behavior under long-running, high-volume signing workloads. As documented in JIRA ticket **[SECURESIGN-1364]**, tests have shown that after approximately 500,000 signatures, the `trillian-db` component can exhaust its allocated storage space. This leads to write failures in the database which cascade up to the client, highlighting the need for capacity planning and storage monitoring in high-volume environments.

### **5. Key Findings and Recommendations**

* **Finding 1: `Affinity` is Key to Performance:** The most impactful optimization was the strategic co-location of `trillian-db` and `trillian-logserver` on the same node, which minimized network latency.
* **Finding 2: Database and Log Server are the Main Bottlenecks:** `trillian-db` and `trillian-logserver` are consistently the most resource-intensive components. Ensuring they have sufficient CPU is essential.
* **Finding 3: Horizontal Scaling Limitation (gRPC):** The most critical finding is that the horizontal scalability of `trillian-logserver` and `ctlog` is currently ineffective due to the default `pick_first` load balancing policy in the gRPC clients.

**Recommendations:**

1.  **Configuration for Higher Performance:** To achieve higher throughput and lower latency, it is essential to apply an optimized profile. This includes both robust `resources` allocation and `affinity` rules for co-locating key components.

The following `resources` block reflects the configuration used to achieve the **~1.29K RPS** benchmark in our specific test environment. It is provided as a recommended starting point for performance tuning. Users should monitor their own application's resource consumption and adjust these values based on their specific cluster size and workload characteristics.


    ```yaml
    resources:
      trillian_database:
        requests: { cpu: "2000m", memory: "1Gi" }
        limits:   { cpu: "4500m", memory: "2Gi" }
      trillian_logserver:
        requests: { cpu: "2000m", memory: "128Mi" }
        limits:   { cpu: "4500m", memory: "512Mi" }
      trillian_logsigner:
        requests: { cpu: "100m", memory: "128Mi" }
        limits:   { cpu: "1000m", memory: "256Mi" }
      rekor:
        requests: { cpu: "1250m", memory: "128Mi" }
        limits:   { cpu: "2500m", memory: "512Mi" }
      fulcio:
        requests: { cpu: "750m", memory: "128Mi" }
        limits:   { cpu: "1500m", memory: "256Mi" }
      ctlog:
        requests: { cpu: "250m", memory: "128Mi" }
        limits:   { cpu: "1000m", memory: "256Mi" }
      tsa:
        requests: { cpu: "100m", memory: "128Mi" }
        limits:   { cpu: "500m", memory: "256Mi" }
    ```

