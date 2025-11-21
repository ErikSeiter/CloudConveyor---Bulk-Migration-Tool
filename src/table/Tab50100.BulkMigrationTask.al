
table 50100 "Bulk Migration Task"
{
    Caption = 'Bulk Migration Task';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Line No."; Integer)
        {
            Caption = 'Line No.';
            AutoIncrement = true;
        }
        field(10; "Migration Name"; Text[100])
        {
            Caption = 'Migration Name';
        }
        field(20; "SQL Connection String"; Text[2048])
        {
            Caption = 'SQL Connection String';
            ExtendedDatatype = Masked;
        }
        field(30; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Pending,"In Progress","Partially Completed",Completed,Replicating,Finished,Failed;
            InitValue = Pending;
        }
        field(40; "Error Text"; Text[2048])
        {
            Caption = 'Error Text';
        }
        field(50; "Progress Step"; Option)
        {
            Caption = 'Progress Step';
            OptionMembers = " ","Configuring Setup","Connecting to SQL","Selecting Companies","Finalizing Setup","Creating Companies","Waiting for Creation","Checks Complete","Replication Started","Waiting for Replication","Pausing Migration";
        }
        field(60; "Retrieved Companies"; Text[2048])
        {
            Caption = 'Retrieved Companies';
        }
        field(70; "Finished Companies"; Text[2048])
        {
            Caption = 'Finished Companies';
        }
        field(80; "Multiple Companies"; Boolean)
        {
            Caption = 'Multiple Companies';
        }
        field(90; "OnPrem Tenant ID"; Text[100])
        {
            Caption = 'OnPrem Tenant ID';
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
    }
}
