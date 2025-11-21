codeunit 50126 "Bulk Migration Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Bulk Migration Setup";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert();
        end;
        // Note: Job Queue creation logic moved to manual setup or keep simplistic
        // to avoid overwriting admin preferences on upgrade.
    end;
}