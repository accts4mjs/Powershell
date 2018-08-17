# Test cases for jiraSetupReleaseCards.ps1
. $env:PSBIN\jiraSetupReleaseCards.ps1

$JSRC_cred = $null
[string]$JSRC_credentialFile = "$($env:USERPROFILE)\.jiraSetupCred.txt"
[string]$JSRC_username = "mshelton"
[string]$JSRC_encryptedPasswd = "01000000d08c9ddf0115d1118c7a00c04fc297eb010000006ade87af1f364b44975ec864b131b3120000000002000000000003660000c0000000100000000783121d493b610ca41080998e99cb4d0000000004800000a000000010000000a1b43220e884298a4527251cbb4f16ac180000000c0eb0058b7a01ae73
9cc33dce968bf957e6ef7661554d8814000000f4ca27270d0337dd08b08ea03a0d8af65e1925c7"
[string]$JSRC_servername = "https://ivinci.atlassian.net"

# Initialize tests
Function Test-JSRC-Initialization() {
    # Remove settings file before each test (unless testing settings file)
    
    Write-Host "** No settings, both parms"
    if (Test-Path $JSRC_credentialFile) {
        Remove-Item -LiteralPath $JSRC_credentialFile
    }
    JiraCardsInit $JSRC_username $JSRC_servername

    Write-Host "** No settings, user parm"
    if (Test-Path $JSRC_credentialFile) {
        Remove-Item -LiteralPath $JSRC_credentialFile
    }
    JiraCardsInit -username $JSRC_username
    Write-Host "** No settings, server parm"
    if (Test-Path $JSRC_credentialFile) {
        Remove-Item -LiteralPath $JSRC_credentialFile
    }
    JiraCardsInit -server $JSRC_servername

    Write-Host "** No settings, no parms"
    if (Test-Path $JSRC_credentialFile) {
        Remove-Item -LiteralPath $JSRC_credentialFile
    }
    JiraCardsInit

    Write-Host "** Settings, no parms"
    JiraCardsInit

    Write-Host "** Settings, user parm"
    JiraCardsInit -username $JSRC_username
    Write-Host "** Settings, server parm"
    JiraCardsInit -server $JSRC_servername
}


Function Test-JSRC-RunAllTests() {
    Test-JSRC-Initialization
}