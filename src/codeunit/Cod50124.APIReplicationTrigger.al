codeunit 50124 "API Replication Trigger"
{
    trigger OnRun()
    var
        Msg: Text;
    begin
        if RunReplicationNow(Msg) then
            Message('Success: %1', Msg)
        else
            Message('Failed: %1', Msg);
    end;

    procedure RunReplicationNow(var StatusMessage: Text): Boolean
    var
        MigrationSetup: Record "Bulk Migration Setup";
        AccessToken: Text;
        CompanyID: Text;
        EnvironmentName: Text;
        EnvInfo: Codeunit "Environment Information";
        Company: Record Company;
        LastRunId: Text;
    begin
        if not MigrationSetup.Get() then exit(false);

        // 1. Authenticate
        if not GetAuthToken(MigrationSetup, AccessToken, StatusMessage) then
            exit(false);

        // 2. Get Context
        EnvironmentName := EnvInfo.GetEnvironmentName();
        Company.Get(CompanyName());
        CompanyID := DelChr(Company.Id, '=', '{}');

        // 3. Get Last Status to find RunID
        if not GetLastMigrationId(AccessToken, CompanyID, LastRunId, StatusMessage) then
            exit(false);

        // 4. Refresh Status via API
        RefreshStatus(AccessToken, CompanyID, LastRunId);

        // 5. Trigger Replication
        exit(TriggerRunReplication(AccessToken, CompanyID, LastRunId, StatusMessage));
    end;

    [NonDebuggable]
    local procedure GetAuthToken(Setup: Record "Bulk Migration Setup"; var Token: Text; var ErrorMsg: Text): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        Body: Text;
        Url: Text;
        Json: JsonObject;
        JToken: JsonToken;
        TenantId: Text;
        AzureAdTenant: Codeunit "Tenant Information";
    begin
        TenantId := AzureAdTenant.GetTenantId();
        Url := 'https://login.microsoftonline.com/' + TenantId + '/oauth2/v2.0/token';

        Body := 'client_id=' + Setup."API Client ID" +
                '&scope=https://api.businesscentral.dynamics.com/.default' +
                '&client_secret=' + Setup."API Client Secret" +
                '&grant_type=client_credentials';

        Content.WriteFrom(Body);

        Content.GetHeaders(ContentHeaders);

        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/x-www-form-urlencoded');

        Client.DefaultRequestHeaders.Clear();

        if not Client.Post(Url, Content, Response) then begin
            ErrorMsg := 'Auth Connection failed';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            ErrorMsg := 'Auth Failed: ' + Format(Response.HttpStatusCode());
            exit(false);
        end;

        Response.Content().ReadAs(Body);
        Json.ReadFrom(Body);
        if Json.Get('access_token', JToken) then begin
            Token := JToken.AsValue().AsText();
            exit(true);
        end;
        exit(false);
    end;

    local procedure GetLastMigrationId(Token: Text; CompanyId: Text; var RunId: Text; var ErrorMsg: Text): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Url: Text;
        ResponseTxt: Text;
        Json: JsonObject;
        JToken: JsonToken;
        EnvInfo: Codeunit "Environment Information";
        TenantInfo: Codeunit "Tenant Information";
    begin
        Url := StrSubstNo('https://api.businesscentral.dynamics.com/v2.0/%1/%2/api/microsoft/cloudMigration/v1.0/companies(%3)/cloudMigrationStatus',
               TenantInfo.GetTenantId(), EnvInfo.GetEnvironmentName(), CompanyId);

        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token);

        if Client.Get(Url, Response) then
            if Response.IsSuccessStatusCode() then begin
                Response.Content().ReadAs(ResponseTxt);
                Json.ReadFrom(ResponseTxt);
                // Assuming the API returns a list, get the first/latest
                if Json.SelectToken('value[0].id', JToken) then begin
                    RunId := JToken.AsValue().AsText();
                    exit(true);
                end;
            end;

        ErrorMsg := 'Could not retrieve migration status ID';
        exit(false);
    end;

    local procedure RefreshStatus(Token: Text; CompanyId: Text; RunId: Text)
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Url: Text;
        EnvInfo: Codeunit "Environment Information";
        TenantInfo: Codeunit "Tenant Information";
    begin
        Url := StrSubstNo('https://api.businesscentral.dynamics.com/v2.0/%1/%2/api/microsoft/cloudMigration/v1.0/companies(%3)/cloudMigrationStatus(%4)/Microsoft.NAV.refreshStatus',
               TenantInfo.GetTenantId(), EnvInfo.GetEnvironmentName(), CompanyId, RunId);

        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token);
        Content.WriteFrom(''); // Empty Post
        Client.Post(Url, Content, Response);
    end;

    local procedure TriggerRunReplication(Token: Text; CompanyId: Text; RunId: Text; var ErrorMsg: Text): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Content: HttpContent;
        Url: Text;
        EnvInfo: Codeunit "Environment Information";
        TenantInfo: Codeunit "Tenant Information";
        Txt: Text;
    begin
        Url := StrSubstNo('https://api.businesscentral.dynamics.com/v2.0/%1/%2/api/microsoft/cloudMigration/v1.0/companies(%3)/cloudMigrationStatus(%4)/Microsoft.NAV.runReplication',
               TenantInfo.GetTenantId(), EnvInfo.GetEnvironmentName(), CompanyId, RunId);

        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token);
        Content.WriteFrom('');

        if not Client.Post(Url, Content, Response) then begin
            ErrorMsg := 'Connection Error';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(Txt);
            ErrorMsg := StrSubstNo('API Error: %1 - %2', Response.HttpStatusCode(), Txt);
            exit(false);
        end;

        ErrorMsg := 'Replication triggered successfully via API.';
        exit(true);
    end;
}