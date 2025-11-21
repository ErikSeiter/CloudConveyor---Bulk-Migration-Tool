
page 50101 "Bulk Migration Setup"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "Bulk Migration Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Automation)
            {
                field("Automation Active"; Rec."Automation Active") { ApplicationArea = All; Caption = 'Enable Automation'; }
                field("Notification Email"; Rec."Notification Email") { ApplicationArea = All; Caption = 'Notification Email Address'; }
            }
            group(AzureIntegration)
            {
                Caption = 'Azure Integration';
                field("Enable Azure Import"; Rec."Enable Azure Import") { ApplicationArea = All; Caption = 'Enable Azure Import'; }
                field("Azure Endpoint URL"; Rec."Azure Endpoint URL") { ApplicationArea = All; Caption = 'Azure Endpoint URL'; }
            }
            group(API)
            {
                Caption = 'BC Admin API';
                field("API Client ID"; Rec."API Client ID") { ApplicationArea = All; Caption = 'API Client ID'; }
                field("API Client Secret"; Rec."API Client Secret") { ApplicationArea = All; Caption = 'API Client Secret'; }
            }
            group(CSV)
            {
                Caption = 'CSV Configuration';
                field("Database Column"; Rec."Database Column") { ApplicationArea = All; Caption = 'Database Column'; }
                field("Company Name Column"; Rec."Company Name Column") { ApplicationArea = All; Caption = 'Company Name Column'; }
                field("SQL String Column"; Rec."SQL String Column") { ApplicationArea = All; Caption = 'SQL String Column'; }
                field("CSV Field Separator"; Rec."CSV Field Separator") { ApplicationArea = All; Caption = 'CSV Field Separator'; }
            }
        }
    }
}