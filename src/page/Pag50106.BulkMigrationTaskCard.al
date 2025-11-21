
page 50106 "Bulk Migration Task Card"
{
    PageType = Card;
    SourceTable = "Bulk Migration Task";

    layout
    {
        area(content)
        {
            group(Details)
            {
                field("OnPrem Tenant ID"; Rec."OnPrem Tenant ID") { ApplicationArea = All; Caption = 'OnPrem Tenant ID'; }
                field("Migration Name"; Rec."Migration Name") { ApplicationArea = All; Caption = 'Migration Name'; }
                field("SQL Connection String"; Rec."SQL Connection String") { ApplicationArea = All; Caption = 'SQL Connection String'; }
                field(Status; Rec.Status) { ApplicationArea = All; Caption = 'Status'; }
                field("Progress Step"; Rec."Progress Step") { ApplicationArea = All; Caption = 'Progress Step'; }
                field("Error Text"; Rec."Error Text") { ApplicationArea = All; Caption = 'Error Text'; MultiLine = true; }
            }
            group(Debug)
            {
                Caption = 'Technical Details';
                field("Retrieved Companies"; Rec."Retrieved Companies") { ApplicationArea = All; Caption = 'Retrieved Companies'; }
                field("Finished Companies"; Rec."Finished Companies") { ApplicationArea = All; Caption = 'Finished Companies'; }
                field("Multiple Companies"; Rec."Multiple Companies") { ApplicationArea = All; Caption = 'Multiple Companies'; }
            }
        }
    }
}