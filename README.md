# ☁️ CloudConveyor: Bulk Cloud Migration Tool

![Platform](https://img.shields.io/badge/Platform-Business%20Central-blue)
![Target](https://img.shields.io/badge/Target-SaaS-success)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**CloudConveyor** is a Business Central extension designed to automate the "Intelligent Cloud" onboarding process. It eliminates the manual bottleneck of configuring migration setups one by one, allowing you to migrate hundreds of companies from On-Premise SQL to BC SaaS in a single unattended batch.

---

## 🚀 Key Features

- **📦 Bulk Import:** Upload a CSV with multiple SQL connection strings and target company names.
- **🤖 Full Automation:** Handles the cycle: *Connect → Select Company → Create Company → Trigger Replication*.
- **⚡ API Integration:** Bypasses UI limitations by triggering data replication via the BC Admin API.
- **🏢 Smart Multi-Company:** Detects and handles single SQL databases containing multiple source companies.
- **🔄 Job Queue Ready:** Designed to run 24/7 in the background.

---

## 📋 Prerequisites

1.  **Dynamics 365 Business Central Cloud** environment.
2.  **Self-Hosted Integration Runtime (SHIR)** installed on the source SQL Server.
3.  **Azure App Registration** (Entra ID) with the following API permissions:
    *   `API.ReadWrite.All`
    *   `Automation.ReadWrite.All`
    *   *Grant Admin Consent* is required.

---

## ⚙️ Configuration

### 1. App Setup
Install the extension and navigate to **Bulk Migration Setup**.

| Tab | Field | Description |
| :--- | :--- | :--- |
| **Automation** | `Automation Active` | Enable to allow Job Queue processing. |
| | `Notification Email` | Email address to receive failure alerts. |
| **BC Admin API** | `API Client ID` | Client ID from your Azure App Registration. |
| | `API Client Secret` | Client Secret from your Azure App Registration. |
| **CSV Config** | `Database Col Index` | Column number (0-based) for the Database Name. |
| | `SQL String Col Index` | Column number (0-based) for the SQL Connection String. |
| | `Separator` | Character used to split CSV fields (e.g., `\|`). |

### 2. CSV File Format
The file should not have a header row if your code expects data immediately. Ensure the delimiter matches your setup (default `|`).

**Example:**
```text
PremiseDB_01|Server=MySvr;Database=PremiseDB_01;Uid=User;Pwd=Pass;|Cronus USA
PremiseDB_02|Server=MySvr;Database=PremiseDB_02;Uid=User;Pwd=Pass;|My Company Ltd
```

---

## 🛠️ Usage Workflow

### Step 1: Import
Navigate to the **Manage Bulk Migrations** page. Click **Import CSV** and select your file.

### Step 2: Review
The tasks will appear in the list with status `Pending`.

### Step 3: Process
You have two options:
1.  **Manual:** Click **Process Next Pending** to run one cycle immediately.
2.  **Automated:** Set up a Job Queue Entry for Codeunit `50122` (Migration Job Queue Handler) to run every 5 minutes.

> **Note:** The Job Queue is smart. It checks if a replication is currently active. If yes, it skips the run. If no, it picks up the next company.

---

## 🏗️ Technical Architecture

### The Automation Loop
The `Bulk Migration Management` Codeunit follows this logic:

1.  **Check:** Is a migration already running? If yes, exit.
2.  **Pick:** Find the next `Pending` task (or a `Partially Completed` multi-company task).
3.  **Configure:** Update `Intelligent Cloud Setup` with the specific SQL string.
4.  **Create:** Call `HybridCloudMgmt.CreateCompanies`.
5.  **Wait:** Pause execution until the company is physically created in BC SaaS.
6.  **Trigger:** Call the **Admin API** to start replication.
7.  **Update:** Set status to `Replicating` and exit.

### Status Definitions

| Status | Meaning |
| :--- | :--- |
| `Pending` | Ready to be processed. |
| `In Progress` | Currently configuring SQL or creating the company. |
| `Replicating` | Replication command sent to API. Waiting for BC to finish. |
| `Completed` | Migration logic finished. |
| `Failed` | Error occurred. Check the **Error Text** field. |

---

## ⚠️ Troubleshooting

**"A 'var' argument must be an assignable variable"**
Ensure you are using the updated Codeunit `50124` which utilizes local variables for HTTP Headers.

**Replication doesn't start**
1. Verify Client ID/Secret.
2. Ensure SHIR is online.
3. Check `Migration Log Entry` table for HTTP error codes.

---

> **Disclaimer:** This tool modifies global Cloud Migration settings. Test thoroughly in a Sandbox before Production use.
