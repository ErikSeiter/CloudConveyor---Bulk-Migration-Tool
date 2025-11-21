table 50110 "Migration Log Entry"
{
    Caption = 'Migration Log Entry';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Log DateTime"; DateTime)
        {
            Caption = 'Log DateTime';
        }
        field(20; "Log Message"; Text[2048])
        {
            Caption = 'Log Message';
        }
        field(30; "User ID"; Code[50])
        {
            Caption = 'User ID';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}