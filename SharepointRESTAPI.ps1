# Connect to SharePoint Online
[string]$targetSite = "https://ivincehealth.sharepoint.com/test/"
$targetSiteUri = [System.Uri]$targetSite
[string]$credFile = "$($env:USERPROFILE)\.SharepointPSSetupCred.txt"
$credentials = $null

function SPRA-ClearSettings () {
    if (Test-Path -PathType Leaf -Path ($credFile)) {
        Remove-Item -LiteralPath ($credFile)
    }
}    

function SPRA-Connect () {
    # Check for credentials file otherwise request credentials and save for future use
    if (Test-Path -Path ($credFile) -PathType leaf) {
        $credFileContents = Get-Content $credFile
        if ($credFileContents.Length -ne 2) {
            Write-Error "Incorrect file line length.  Expect username, password.  Length = '$($credFileContents.Length)'"
            Write-Error "Run SPRA-ClearSettings to clear settings file and then re-run this function."
            return
        }
        $securePasswd = ConvertTo-SecureString $credFileContents[1]
        $credentials = New-Object System.Management.Automation.PSCredential($credFileContents[0], $securePasswd)
    } else {
        $credentials = Get-Credential 

        # Save username, encrypted password, and server
        $credentials.UserName | Set-Content ($credFile)
        $securePasswd = ConvertFrom-SecureString -SecureString ($credentials.Password)
        $securePasswd | Add-Content ($credFile)
    }

    Connect-PnPOnline -Url $targetSite -Credentials $credentials
}

function SPRA-Junk () {
    # Retrieve the client credentials and the related Authentication Cookies
    $context = (Get-SPOWeb).Context
    $credentials = $context.Credentials
    $authenticationCookies = $credentials.GetAuthenticationCookie($targetSiteUri, $true)

    # Set the Authentication Cookies and the Accept HTTP Header
    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $webSession.Cookies.SetCookies($targetSiteUri, $authenticationCookies)
    $webSession.Headers.Add(“Accept”, “application/json;odata=verbose”)

    # Set request variables
    $targetLibrary = “Documents”
    $apiUrl = “$targetSite” + “_api/web/lists/getByTitle(‘$targetLibrary’)”

    # Make the REST request
    $webRequest = Invoke-WebRequest -Uri $apiUrl -Method Get -WebSession $webSession

    # Consume the JSON result
    $jsonLibrary = $webRequest.Content | ConvertFrom-Json
    Write-Host $jsonLibrary.d.Title
}

function SPRA-Junk2 () {
    # Retrieve client context credentials and cookies
    $ctx = Get-PnPContext
    Get-PnPList -Identity "Lists/Change Requests"
}

function SPRA-Junk3 () {
#    $listItems = (Get-PnPListItem -List "TestList" -Fields "ID","Short Description","Change Status","Jira Card Reference").FieldValues
    $listItems = Get-PnPListItem -List "Lists\TestList"
    Write-Host "Number of items: " $listItems.Length
    $i = 1
    foreach ($item in $listItems) {
        $item
        Write-Host "-----------------------------------------"
        $i++
        if ($i -gt 5) {break}
    }
}

function SPRA-Junk4 () {
    $listItems = Get-PnPListItem -List "TestList" -Query "
        <View><Query><Where><In>
            <FieldRef Name='Id' LookupId='True'/>
            <Values>
                <Value Type = 'Text'>9</Value>
                <Value Type = 'Text'>10</Value>
                <Value Type = 'Text'>11</Value>
                <Value Type = 'Text'>12</Value>
                <Value Type = 'Text'>15</Value>
            </Values>
        </In></Where></Query></View>"
    Write-Host "Number of items: " $listItems.Length
    $i = 1
    foreach ($item in $listItems) {
        $item
        Write-Host "-----------------------------------------"
        $i++
        if ($i -gt 5) {break}
    }
}

function SPRA-Junk5 () {
    $listItems = Get-PnPListItem -List "Lists/TestList" -Query "
        <View><Query><Where><Eq>
            <FieldRef Name='Id'/>
                <Value Type='Id'>9</Value>
        </Eq></Where></Query></View>"
    Write-Host "Number of items: " $listItems.Length
    $i = 1
    foreach ($item in $listItems) {
        $item
        Write-Host "-----------------------------------------"
        $i++
        if ($i -gt 5) {break}
    }
}

function SPRA-Junk6 () {
    $listItems = Get-PnPListItem -List "Lists/Mshelton" -Query "
        <View><Query><Where><Eq>
            <FieldRef Name='Id'/>
                <Value Type='Counter'>1</Value>
        </Eq></Where></Query></View>"
#    $listItems = Get-PnPListItem -List "Lists/Mshelton"
    Write-Host "Number of items: " $listItems.Length
    $i = 1
    foreach ($item in $listItems) {
        $item
        Write-Host "-----------------------------------------"
        $i++
        if ($i -gt 5) {break}
    }
}