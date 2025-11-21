table 50101 "Bulk Migration Setup"
{
    Caption = 'Bulk Migration Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(20; "Automation Active"; Boolean)
        {
            Caption = 'Automation Active';
        }
        field(30; "Current Migration Active"; Boolean)
        {
            Caption = 'Current Migration Active';
            Description = 'Internal flag to prevent concurrent runs';
        }
        // Import Configuration
        field(60; "Company Name Column"; Integer)
        {
            Caption = 'Company Name Column Index';
        }
        field(70; "Database Column"; Integer)
        {
            Caption = 'Database Column Index';
        }
        field(80; "SQL String Column"; Integer)
        {
            Caption = 'SQL String Column Index';
        }
        field(90; "CSV Field Separator"; Text[1])
        {
            Caption = 'CSV Field Separator';
            InitValue = '|';
        }
        field(100; "Enable Azure Import"; Boolean)
        {
            Caption = 'Enable Azure Import';
        }
        field(101; "Azure Endpoint URL"; Text[250])
        {
            Caption = 'Azure Function Endpoint';
            Description = 'URL for the middleware service';
        }
        field(110; "Notification Email"; Text[250])
        {
            Caption = 'Notification Email';
        }
        // API Configuration
        field(120; "API Client ID"; Text[100])
        {
            Caption = 'API Client ID';
        }
        field(130; "API Client Secret"; Text[100])
        {
            Caption = 'API Client Secret';
            ExtendedDatatype = Masked;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}

