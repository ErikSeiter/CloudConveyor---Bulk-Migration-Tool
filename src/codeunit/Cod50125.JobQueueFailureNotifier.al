codeunit 50125 "Job Queue Failure Notifier"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Error Handler", 'OnAfterLogError', '', true, true)]
    procedure OnJobQueueError(var JobQueueLogEntry: Record "Job Queue Log Entry")
    var
        Email: Codeunit Email;
        EmailMessage: Codeunit "Email Message";
        Setup: Record "Bulk Migration Setup";
        Subject: Text;
        Body: Text;
    begin
        if not Setup.Get() then exit;
        if Setup."Notification Email" = '' then exit;

        Subject := StrSubstNo('Migration Job Failed: %1', JobQueueLogEntry."Object Caption to Run");
        Body := StrSubstNo('Job ID: %1\Error: %2', JobQueueLogEntry."Entry No.", JobQueueLogEntry."Error Message");

        EmailMessage.Create(Setup."Notification Email", Subject, Body);
        Email.Send(EmailMessage, Enum::"Email Scenario"::Default);
    end;
}