codeunit 50120 "Bulk Migration Management"
{
    Access = Public;

    var
        LogSetupSuccessMsg: Label 'Automated configuration of cloud migration was completed successfully.';
        NoPendingTasksMsg: Label 'There are no pending migration tasks to process.';
        ProcessingTaskLbl: Label 'Processing migration for: %1';
        ProductIDConst: Label 'DynamicsBCLast', Locked = true;
        ReplicationFailedMsg: Label 'Replication failed. Check migration log for details.';
        MigrationInProgressErr: Label 'A migration is already in progress.';
        CompanyCreationRunningErr: Label 'A previous company creation process is still running.';

    trigger OnRun()
    begin
        ProcessNextPendingTask();
    end;

    procedure ProcessNextPendingTask()
    var
        BulkMigrationTask: Record "Bulk Migration Task";
        BulkMigrationSetup: Record "Bulk Migration Setup";
    begin
        CreateLogEntry('ProcessNextPendingTask: Start');

        // Priority 1: Continue multi-company tasks that are partially done
        BulkMigrationTask.SetRange("Multiple Companies", true);
        if BulkMigrationTask.FindFirst() then begin
            CreateLogEntry(StrSubstNo('Found multi-company task. Line No: %1', BulkMigrationTask."Line No."));
            ExecuteMigrationTask(BulkMigrationTask);
            exit;
        end;

        // Priority 2: Pick up new pending tasks
        BulkMigrationTask.Reset();
        BulkMigrationTask.SetRange(Status, BulkMigrationTask.Status::Pending);
        if not BulkMigrationTask.FindFirst() then begin
            CreateLogEntry('No pending tasks found. Exiting.');
            exit;
        end;

        CreateLogEntry(StrSubstNo('Starting new task. Line No: %1', BulkMigrationTask."Line No."));
        ExecuteMigrationTask(BulkMigrationTask);

        CleanupOldLogEntries();
    end;

    local procedure ExecuteMigrationTask(var BulkMigrationTask: Record "Bulk Migration Task")
    var
        BulkMigrationSetup: Record "Bulk Migration Setup";
        ErrorMessage: Text;
    begin
        if not BulkMigrationSetup.Get() then exit;

        // Lock the process
        BulkMigrationSetup."Current Migration Active" := true;
        BulkMigrationSetup.Modify();

        if not ExecuteFullMigrationCycle(BulkMigrationTask, ErrorMessage) then begin
            // Handle Failure
            BulkMigrationTask.Validate(Status, BulkMigrationTask.Status::Failed);
            BulkMigrationTask.Validate("Error Text", CopyStr(ErrorMessage, 1, MaxStrLen(BulkMigrationTask."Error Text")));
            BulkMigrationTask.Modify();

            BulkMigrationSetup."Current Migration Active" := false;
            BulkMigrationSetup.Modify();

            CreateLogEntry(StrSubstNo('Task Failed: %1', ErrorMessage));
        end else begin
            // Handle Success
            CreateLogEntry('Task Cycle Completed Successfully.');
            BulkMigrationSetup."Current Migration Active" := false;
            BulkMigrationSetup.Modify();
        end;
    end;

    [TryFunction]
    local procedure ExecuteFullMigrationCycle(var BulkMigrationTask: Record "Bulk Migration Task"; var ErrorMessage: Text)
    var
        HybridReplicationSummary: Record "Hybrid Replication Summary";
        HybridCompany: Record "Hybrid Company";
    begin
        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"In Progress", BulkMigrationTask."Progress Step"::"Configuring Setup");

        // 1. Configure Intelligent Cloud and Select Companies
        if not ExecuteSetupLogic(BulkMigrationTask, ErrorMessage, HybridCompany) then
            Error(ErrorMessage);

        // 2. Mark Setup as Done in Summary
        if HybridReplicationSummary.FindLast() then begin
            HybridReplicationSummary.SetDetails(LogSetupSuccessMsg);
            HybridReplicationSummary.Modify();
        end;

        // 3. Handle Multi-Company Logic status updates
        HandleTaskCompletionStatus(BulkMigrationTask, HybridCompany);

        // 4. Start Replication
        // Note: Sleep is required here as the BC backend needs time to release the company creation locks before accepting replication requests.
        Sleep(100000);

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"In Progress", BulkMigrationTask."Progress Step"::"Replication Started");

        if not StartReplicationWithRetry(BulkMigrationTask) then
            Error('Failed to start data replication after multiple attempts.');

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::Replicating, BulkMigrationTask."Progress Step"::"Waiting for Replication");
    end;

    local procedure ExecuteSetupLogic(var BulkMigrationTask: Record "Bulk Migration Task"; var ErrorMessage: Text; var HybridCompany: Record "Hybrid Company"): Boolean
    var
        IntelligentCloudSetup: Record "Intelligent Cloud Setup";
        TempHybridProductType: Record "Hybrid Product Type" temporary;
        HybridCloudMgmt: Codeunit "Hybrid Cloud Management";
        RetrievedCompanyList: Text;
        NextCompany: Text;
        HybridCompanyTemp: Record "Hybrid Company" temporary;
    begin
        if IsCompanyCreationInProgress() then begin
            ErrorMessage := CompanyCreationRunningErr;
            exit(false);
        end;

        // If not already processing multiple companies, do the initial SQL connection and retrieval
        if not BulkMigrationTask."Multiple Companies" then begin
            BulkMigrationTask."Retrieved Companies" := '';

            // Ensure Setup Record Exists
            if not IntelligentCloudSetup.Get() then begin
                IntelligentCloudSetup.Init();
                IntelligentCloudSetup.Insert();
            end;

            IntelligentCloudSetup.Validate("Product ID", ProductIDConst);
            IntelligentCloudSetup.Validate("Sql Server Type", IntelligentCloudSetup."Sql Server Type"::AzureSQL);
            IntelligentCloudSetup.Modify();

            HybridCloudMgmt.RestoreDefaultMigrationTableMappings(false);

            // Snapshot existing hybrid companies to identify new ones after connection
            HybridCompany.Reset();
            if HybridCompany.FindSet() then
                repeat
                    HybridCompanyTemp := HybridCompany;
                    HybridCompanyTemp.Insert();
                until HybridCompany.Next() = 0;

            UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"In Progress", BulkMigrationTask."Progress Step"::"Connecting to SQL");

            TempHybridProductType.ID := ProductIDConst;
            HybridCloudMgmt.HandleShowCompanySelectionStep(TempHybridProductType, BulkMigrationTask."SQL Connection String", 'AzureSQL', '');

            // Identify newly retrieved companies
            HybridCompany.Reset();
            if HybridCompany.FindSet() then
                repeat
                    if not HybridCompanyTemp.Get(HybridCompany."Name") then
                        RetrievedCompanyList += HybridCompany."Name" + ';';
                until HybridCompany.Next() = 0;

            BulkMigrationTask."Retrieved Companies" := CopyStr(RetrievedCompanyList, 1, MaxStrLen(BulkMigrationTask."Retrieved Companies"));
            BulkMigrationTask.Modify();
        end;

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"Partially Completed", BulkMigrationTask."Progress Step"::"Selecting Companies");

        // Disable replication for all, then enable for the specific target company
        HybridCompany.Reset();
        HybridCompany.ModifyAll(Replicate, false);

        DetermineNextCompanyToReplicate(BulkMigrationTask, NextCompany);

        if NextCompany <> '' then begin
            HybridCompany.SetRange(Name, NextCompany);
            if HybridCompany.FindFirst() then begin
                HybridCompany.Replicate := true;
                HybridCompany.Modify();
            end;
        end else begin
            ErrorMessage := 'No company found to replicate.';
            exit(false);
        end;

        // Finalize User and Create Companies
        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"Partially Completed", BulkMigrationTask."Progress Step"::"Finalizing Setup");

        IntelligentCloudSetup.Get();
        IntelligentCloudSetup.Validate("Replication User", UserId());
        IntelligentCloudSetup.Modify();

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"Partially Completed", BulkMigrationTask."Progress Step"::"Creating Companies");
        HybridCloudMgmt.CreateCompanies();
        Commit(); // Commit before waiting

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"Partially Completed", BulkMigrationTask."Progress Step"::"Waiting for Creation");

        if not WaitForCompanyCreationToFinalize(ErrorMessage) then
            exit(false);

        if not PerformPreReplicationChecks(ErrorMessage) then
            exit(false);

        UpdateTaskStatus(BulkMigrationTask, BulkMigrationTask.Status::"Partially Completed", BulkMigrationTask."Progress Step"::"Checks Complete");
        exit(true);
    end;

    local procedure DetermineNextCompanyToReplicate(var BulkMigrationTask: Record "Bulk Migration Task"; var NextCompany: Text)
    var
        RetrievedList: List of [Text];
        FinishedList: List of [Text];
        Company: Text;
    begin
        NextCompany := '';

        if BulkMigrationTask."Retrieved Companies" = '' then exit;

        RetrievedList := BulkMigrationTask."Retrieved Companies".Split(';');
        if BulkMigrationTask."Finished Companies" <> '' then
            FinishedList := BulkMigrationTask."Finished Companies".Split(';');

        foreach Company in RetrievedList do
            if (Company.Trim() <> '') and (not FinishedList.Contains(Company.Trim())) then begin
                NextCompany := Company.Trim();
                break;
            end;


        // Update Task Metadata
        if NextCompany <> '' then
            if BulkMigrationTask."Finished Companies" = '' then
                BulkMigrationTask."Finished Companies" := NextCompany
            else
                BulkMigrationTask."Finished Companies" += ';' + NextCompany;

        // Check if more remain
        BulkMigrationTask."Multiple Companies" := (RetrievedList.Count > (FinishedList.Count + 1)); // +1 because we just added one
        BulkMigrationTask.Modify();
    end;

    local procedure StartReplicationWithRetry(var BulkMigrationTask: Record "Bulk Migration Task"): Boolean
    var
        Attempt: Integer;
        Success: Boolean;
    begin
        for Attempt := 1 to 3 do begin
            if TryStartReplication(BulkMigrationTask) then
                exit(true);
            Sleep(10000); // Wait before retry
        end;
        exit(false);
    end;

    [TryFunction]
    local procedure TryStartReplication(var BulkMigrationTask: Record "Bulk Migration Task")
    var
        APIReplicationTrigger: Codeunit "API Replication Trigger";
        ErrorMessage: Text;
    begin
        if APIReplicationTrigger.RunReplicationNow(ErrorMessage) then begin
            BulkMigrationTask.Validate(Status, BulkMigrationTask.Status::Replicating);
            BulkMigrationTask.Modify();
            Commit();
        end else
            Error(ErrorMessage);
    end;

    local procedure UpdateTaskStatus(var Task: Record "Bulk Migration Task"; NewStatus: Option; NewStep: Option)
    begin
        Task.Validate(Status, NewStatus);
        Task.Validate("Progress Step", NewStep);
        Task.Modify();
        Commit();
    end;

    local procedure HandleTaskCompletionStatus(var BulkMigrationTask: Record "Bulk Migration Task"; HybridCompany: Record "Hybrid Company")
    var
        TaskInList: Record "Bulk Migration Task";
    begin
        if not BulkMigrationTask."Multiple Companies" then begin
            BulkMigrationTask.Validate(Status, BulkMigrationTask.Status::Completed);
        end;
        // Logic to mark related tasks as completed if they share the same company name pattern
        // (Refactored from original code, assuming logic was intended to deduce duplicates)
        TaskInList.SetFilter("Retrieved Companies", '@*' + HybridCompany.Name + '*');
        if TaskInList.FindSet() then
            TaskInList.ModifyAll(Status, TaskInList.Status::Completed);

        BulkMigrationTask.Modify();
        Commit();
    end;

    #region Helper Functions
    local procedure WaitForCompanyCreationToFinalize(var ErrorMessage: Text): Boolean
    var
        IntelligentCloudSetup: Record "Intelligent Cloud Setup";
        StartTime: DateTime;
    begin
        // Wait loop (max 5 mins)
        StartTime := CurrentDateTime();

        while IsCompanyCreationInProgress() do begin
            if (CurrentDateTime() - StartTime) > (5 * 60 * 1000) then begin
                ErrorMessage := 'Timeout waiting for company creation.';
                exit(false);
            end;
            Sleep(10000);
        end;

        if IntelligentCloudSetup.Get() then
            if IntelligentCloudSetup."Company Creation Task Status" = IntelligentCloudSetup."Company Creation Task Status"::Failed then begin
                ErrorMessage := IntelligentCloudSetup."Company Creation Task Error";
                exit(false);
            end;

        exit(true);
    end;

    local procedure IsCompanyCreationInProgress(): Boolean
    var
        IntelligentCloudSetup: Record "Intelligent Cloud Setup";
        ScheduledTask: Record "Scheduled Task";
    begin
        if not IntelligentCloudSetup.Get() then exit(false);

        if not IsNullGuid(IntelligentCloudSetup."Company Creation Task ID") then
            exit(ScheduledTask.Get(IntelligentCloudSetup."Company Creation Task ID"));

        if IntelligentCloudSetup."Company Creation Session ID" <> 0 then
            exit(Session.IsSessionActive(IntelligentCloudSetup."Company Creation Session ID"));

        exit(false);
    end;

    local procedure PerformPreReplicationChecks(var ErrorMessage: Text): Boolean
    var
        HybridReplicationSummary: Record "Hybrid Replication Summary";
    begin
        HybridReplicationSummary.SetRange(Status, HybridReplicationSummary.Status::InProgress);
        // Check for replications started in last 24h that are still running
        HybridReplicationSummary.SetFilter("Start Time", '>%1', (CurrentDateTime() - 86400000));
        if not HybridReplicationSummary.IsEmpty() then begin
            ErrorMessage := MigrationInProgressErr;
            exit(false);
        end;
        exit(true);
    end;

    procedure CreateLogEntry(Message: Text)
    var
        LogRec: Record "Migration Log Entry";
    begin
        LogRec.Init();
        LogRec."Log DateTime" := CurrentDateTime();
        LogRec."Log Message" := CopyStr(Message, 1, MaxStrLen(LogRec."Log Message"));
        LogRec."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogRec."User ID"));
        LogRec.Insert();
        Commit();
    end;

    local procedure CleanupOldLogEntries()
    var
        LogRec: Record "Migration Log Entry";
    begin
        // Keep logs for 24 hours
        LogRec.SetFilter("Log DateTime", '<%1', CurrentDateTime() - (24 * 60 * 60 * 1000));
        LogRec.DeleteAll();
        Commit();
    end;
    #endregion
}
