Bulk Cloud Migration Tool for Business Central
Overview
The Bulk Cloud Migration Tool is a Business Central AL extension designed to automate the onboarding and data migration of multiple companies from on-premises SQL databases to Dynamics 365 Business Central Cloud.
Standard Cloud Migration requires manual configuration for every single company. This tool solves that bottleneck by:
Importing a list of migration targets (from CSV or Azure Middleware).
Automatically configuring the Intelligent Cloud Setup.
Creating the companies in BC Cloud.
Triggering the data replication via the Admin API.
Looping through the queue until all companies are migrated.
Key Features
Bulk Import: Upload a CSV containing Database names, SQL Connection Strings, and Target Company Names.
Full Automation: Handles the complete lifecycle: Connect -> Select Company -> Create Company -> Trigger Replication.
Multi-Company Handling: Smart logic to handle single SQL Connection Strings that contain multiple source companies.
API Integration: Uses the Business Central Admin API to trigger replications programmatically (bypassing UI limitations).
Job Queue Ready: Can run in the background to process migrations sequentially 24/7.
Error Handling: detailed logging and email notifications upon failure.
Prerequisites
Dynamics 365 Business Central Cloud environment.
Self-Hosted Integration Runtime (SHIR) installed and configured on the source SQL server (required for the standard Cloud Migration connection).
Entra ID (Azure AD) App Registration:
Required for the tool to call the BC Admin API to trigger replication.
Permissions: API.ReadWrite.All, Automation.ReadWrite.All (Delegated or Application depending on setup, usually Application for background tasks).
Scope: https://api.businesscentral.dynamics.com/.default
Setup & Configuration
1. App Setup
Install the Extension.
Navigate to Bulk Migration Setup.
Fill in the following fields:
Tab	Field	Description
Automation	Automation Active	Enable to allow Job Queue processing.
Notification Email	Email address to receive failure alerts.
Azure Integration	Azure Endpoint URL	(Optional) URL if fetching migration list from middleware.
BC Admin API	API Client ID	Client ID from your Azure App Registration.
API Client Secret	Client Secret from your Azure App Registration.
CSV Config	Database Col Index	Column number (0-based) for the Database Name.
Company Name Col Index	Column number (0-based) for the Company Name.
SQL String Col Index	Column number (0-based) for the SQL Connection String.
Separator	Character used to split CSV fields (e.g., `
2. CSV File Format
Prepare a CSV file (no headers required, but indexes must match Setup).
Example (using | separator and Setup indexes: DB=0, SQL=1, Name=2):
code
Text
PremiseDB_01|Server=MyServer;Database=PremiseDB_01;Uid=User;Pwd=Pass;|Cronus USA
PremiseDB_02|Server=MyServer;Database=PremiseDB_02;Uid=User;Pwd=Pass;|My Company Ltd
3. Job Queue Setup (Optional but Recommended)
To run migrations unattended:
Create a Job Queue Entry.
Object Type: Codeunit
Object ID: 50122 (Migration Job Queue Handler).
Set it to recur (e.g., every 5 minutes).
Note: The Codeunit checks if a migration is currently active. If yes, it skips; if no, it picks up the next pending task.
Usage Workflow
Open the Dashboard:
Navigate to Cloud Migration Management and click Manage Bulk Migrations (or search for Bulk Migration Tasks).
Import Tasks:
Click Import CSV to upload your prepared file.
Alternatively, click Import from Azure if you have a middleware endpoint configured.
Review Queue:
Verify the tasks loaded into the list. Status will be Pending.
Start Migration:
Manual: Click Process Next Pending to run the next task immediately in the current session.
Automated: Start the Job Queue entry created in the Setup phase.
Monitor:
Watch the Status and Progress Step fields on the Task List.
Log Entries: View Migration Log Entry table for detailed technical logs.
Technical Architecture
The Process Cycle (Codeunit 50120)
Initialization: Checks for Pending tasks. Prioritizes unfinished multi-company tasks.
Configuration:
Initializes Intelligent Cloud Setup.
Connects to SQL using the provided Connection String.
Company Selection:
Retrieves available companies from the SQL source.
Selects the specific company defined in the Task.
Disables replication for all other companies.
Creation:
Calls HybridCloudMgmt.CreateCompanies().
Waits (Sleep loop) for the background session to finish creating the company in BC.
Replication:
Calls Codeunit 50124 (API Replication Trigger).
Acquires an OAuth Token using Client Credentials.
Calls the BC Admin API Microsoft.NAV.runReplication endpoint.
This is necessary because standard AL code cannot trigger the physical data movement without user interaction, but the API can.
Status Codes
Pending: Ready to be picked up.
In Progress: Currently configuring or waiting for company creation.
Replicating: Replication triggered successfully; waiting for BC to finish data transfer.
Completed: Task finished (Logic handles multi-company grouping).
Failed: Error occurred. Check Error Text field.
Troubleshooting
Issue: "A 'var' argument must be an assignable variable" during compilation.
Solution: Ensure you are using the updated Codeunit 50124 provided, which uses local variables for HTTP Headers.
Issue: Replication doesn't start.
Check: Ensure the API Client ID/Secret has permissions to the Business Central tenant.
Check: Ensure the Self-Hosted Integration Runtime is online.
Issue: Timeout waiting for Company Creation.
Cause: Large databases or Azure resource constraints.
Solution: The code waits ~5 minutes. If it takes longer, the task fails to prevent blocking. Check the "Intelligent Cloud Setup" page manually for errors.
Disclaimer
This tool performs administrative actions and modifies global Cloud Migration settings. It should be tested thoroughly in a Sandbox environment before use in Production. Ensure you have valid backups of your on-premises data.
