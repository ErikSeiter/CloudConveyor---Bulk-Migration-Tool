
codeunit 50122 "Migration Job Queue Handler"
{
    trigger OnRun()
    var
        BulkMigrationSetup: Record "Bulk Migration Setup";
        ErrorMessage: Text;
        BulkMgmt: Codeunit "Bulk Migration Management";
    begin
        if not BulkMigrationSetup.Get() then exit;
        if not BulkMigrationSetup."Automation Active" then exit;
        if BulkMigrationSetup."Current Migration Active" then exit;

        // Verify environment state before attempting anything
        if not VerifyCanStart(ErrorMessage) then begin
            BulkMgmt.CreateLogEntry(StrSubstNo('Job Queue Skipped: %1', ErrorMessage));
            exit;
        end;

        // Run the main logic
        BulkMgmt.ProcessNextPendingTask();
    end;

    local procedure VerifyCanStart(var ErrorMessage: Text): Boolean
    var
        HybridReplicationSummary: Record "Hybrid Replication Summary";
    begin
        // Check if standard replication is running
        HybridReplicationSummary.SetRange(Status, HybridReplicationSummary.Status::InProgress);
        HybridReplicationSummary.SetFilter("Start Time", '>%1', CurrentDateTime() - 86400000); // Last 24 hours
        if not HybridReplicationSummary.IsEmpty() then begin
            ErrorMessage := 'A standard replication is currently in progress.';
            exit(false);
        end;
        exit(true);
    end;
}
