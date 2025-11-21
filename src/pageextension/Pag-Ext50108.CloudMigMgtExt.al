pageextension 50108 "Cloud Mig. Mgt. Ext" extends "Cloud Migration Management"
{
    actions
    {
        addafter(RunReplicationNow)
        {
            action(ManageBulkMigration)
            {
                ApplicationArea = All;
                Caption = 'Manage Bulk Migrations';
                ToolTip = 'Open a page to manage and process a queue of migrations from a CSV file.';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Page.Run(Page::"Bulk Migration Task List");
                end;
            }
            action(HybridCompaniesOverview)
            {
                ApplicationArea = All;
                Caption = 'Hybrid Companies Overview';
                ToolTip = 'View the list of companies currently configured for replication.';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    // Opens the standard Hybrid Companies list. 
                    // If you have a custom page, replace with Page::"Your Page Name"
                    Page.Run(Page::"Hybrid Companies");
                end;
            }
        }

        // Hiding the standard Data Upgrade action as requested
        modify(RunDataUpgrade)
        {
            Visible = false;
        }
    }
}