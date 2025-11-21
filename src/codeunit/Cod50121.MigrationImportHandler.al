
codeunit 50121 "Migration Import Handler"
{
    var
        UploadPromptLbl: Label 'Upload the migration CSV file';
        FileFilterLbl: Label 'CSV files (*.csv)|*.csv';
        ImportSummaryMsg: Label 'Import Complete. Inserted: %1. Errors: %2.';
        HttpErrorErr: Label 'HTTP Request failed. Status: %1, Reason: %2';

    procedure UploadAndParseCSV()
    var
        BulkMigrationSetup: Record "Bulk Migration Setup";
        InStream: InStream;
        FileName: Text;
    begin
        if not BulkMigrationSetup.Get() then Error('Setup missing.');

        if UploadIntoStream(UploadPromptLbl, '', FileFilterLbl, FileName, InStream) then
            ParseCSVStream(InStream);
    end;

    local procedure ParseCSVStream(var InStream: InStream)
    var
        BulkMigrationSetup: Record "Bulk Migration Setup";
        BulkMigrationTask: Record "Bulk Migration Task";
        LineText: Text;
        Values: List of [Text];
        InsertedCount: Integer;
        ErrorCount: Integer;
    begin
        BulkMigrationSetup.Get();

        // Skip header
        if not InStream.EOS() then InStream.ReadText(LineText);

        while not InStream.EOS() do begin
            InStream.ReadText(LineText);
            if LineText.Trim() <> '' then begin
                Values := LineText.Split(BulkMigrationSetup."CSV Field Separator");

                // Basic validation logic based on column indexes in setup
                if (Values.Count() >= BulkMigrationSetup."Database Column") and
                   (Values.Count() >= BulkMigrationSetup."SQL String Column") then begin

                    Clear(BulkMigrationTask);
                    BulkMigrationTask."OnPrem Tenant ID" := CopyStr(Values.Get(BulkMigrationSetup."Database Column").Trim(), 1, 100);
                    BulkMigrationTask."SQL Connection String" := CopyStr(Values.Get(BulkMigrationSetup."SQL String Column").Trim(), 1, 2048);
                    BulkMigrationTask."Migration Name" := CopyStr(Values.Get(BulkMigrationSetup."Company Name Column").Trim(), 1, 100);

                    if BulkMigrationTask.Insert(true) then
                        InsertedCount += 1
                    else
                        ErrorCount += 1;
                end else
                    ErrorCount += 1;
            end;
        end;

        Message(ImportSummaryMsg, InsertedCount, ErrorCount);
    end;

    procedure ImportFromAzureMiddleware(Silent: Boolean)
    var
        BulkMigrationSetup: Record "Bulk Migration Setup";
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Log: Codeunit "Bulk Migration Management";
    begin
        if not BulkMigrationSetup.Get() then exit;
        if not BulkMigrationSetup."Enable Azure Import" then exit;
        if BulkMigrationSetup."Azure Endpoint URL" = '' then exit;

        if not Client.Get(BulkMigrationSetup."Azure Endpoint URL", Response) then begin
            if not Silent then Error(HttpErrorErr, '0', 'Connection Failed');
            Log.CreateLogEntry('Azure Import Failed: Connection Error');
            exit;
        end;

        if not Response.IsSuccessStatusCode() then begin
            if not Silent then Error(HttpErrorErr, Response.HttpStatusCode(), Response.ReasonPhrase());
            Log.CreateLogEntry(StrSubstNo('Azure Import Failed: %1 %2', Response.HttpStatusCode(), Response.ReasonPhrase()));
            exit;
        end;

        Response.Content().ReadAs(ResponseText);
        ParseJsonMigrationList(ResponseText);
    end;

    local procedure ParseJsonMigrationList(JsonText: Text)
    var
        JsonObj: JsonObject;
        JsonArr: JsonArray;
        Token: JsonToken;
        ItemObj: JsonObject;
        BulkMigrationTask: Record "Bulk Migration Task";
        DatabaseVal: Text;
        SqlVal: Text;
    begin
        if not JsonObj.ReadFrom(JsonText) then exit;
        if not JsonObj.Get('migrations', Token) then exit;
        if not Token.IsArray() then exit;

        JsonArr := Token.AsArray();
        foreach Token in JsonArr do begin
            ItemObj := Token.AsObject();
            if GetJsonValue(ItemObj, 'database', DatabaseVal) and GetJsonValue(ItemObj, 'sqlString', SqlVal) then begin
                BulkMigrationTask.SetRange("OnPrem Tenant ID", DatabaseVal);
                if BulkMigrationTask.IsEmpty() then begin
                    BulkMigrationTask.Init();
                    BulkMigrationTask."OnPrem Tenant ID" := CopyStr(DatabaseVal, 1, 100);
                    BulkMigrationTask."SQL Connection String" := CopyStr(SqlVal, 1, 2048);
                    BulkMigrationTask.Insert(true);
                end;
            end;
        end;
    end;

    local procedure GetJsonValue(JObj: JsonObject; KeyName: Text; var Result: Text): Boolean
    var
        Token: JsonToken;
    begin
        if JObj.Get(KeyName, Token) then
            if Token.IsValue() then begin
                Result := Token.AsValue().AsText();
                exit(true);
            end;
        exit(false);
    end;
}

