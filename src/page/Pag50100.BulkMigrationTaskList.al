page 50100 "Bulk Migration Task List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Bulk Migration Task";
    Caption = 'Bulk Migration Tasks';
    CardPageId = "Bulk Migration Task Card";

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Line No."; Rec."Line No.") { ApplicationArea = All; Caption = 'Line No.'; }
                field("OnPrem Tenant ID"; Rec."OnPrem Tenant ID") { ApplicationArea = All; Caption = 'OnPrem Tenant ID'; }
                field("Migration Name"; Rec."Migration Name") { ApplicationArea = All; Caption = 'Migration Name'; }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                    Caption = 'Status';
                }
                field("Progress Step"; Rec."Progress Step") { ApplicationArea = All; Caption = 'Progress Step'; }
                field("Error Text"; Rec."Error Text") { ApplicationArea = All; Caption = 'Error Text'; }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ImportCSV)
            {
                ApplicationArea = All;
                Caption = 'Import CSV';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    ImportHandler: Codeunit "Migration Import Handler";
                begin
                    ImportHandler.UploadAndParseCSV();
                    CurrPage.Update(false);
                end;
            }
            action(ProcessNext)
            {
                ApplicationArea = All;
                Caption = 'Process Next Pending';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Mgmt: Codeunit "Bulk Migration Management";
                begin
                    Mgmt.ProcessNextPendingTask();
                end;
            }
            action(ImportAzure)
            {
                ApplicationArea = All;
                Caption = 'Import from Azure';
                Image = Cloud;

                trigger OnAction()
                var
                    ImportHandler: Codeunit "Migration Import Handler";
                begin
                    ImportHandler.ImportFromAzureMiddleware(false);
                    CurrPage.Update(false);
                end;
            }
            action(Setup)
            {
                ApplicationArea = All;
                Caption = 'Setup';
                Image = Setup;
                RunObject = Page "Bulk Migration Setup";
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        StatusStyle := GetStatusStyle();
    end;

    local procedure GetStatusStyle(): Text
    begin
        case Rec.Status of
            Rec.Status::Failed:
                exit('Unfavorable');
            Rec.Status::Completed:
                exit('Favorable');
            Rec.Status::"In Progress":
                exit('Ambiguous');
            else
                exit('Standard');
        end;
    end;
}

