########################################################################
# File: jiraSetupReleaseCards.ps1
#
# Purpose: To establish a credentialed (encrypted) connection to a 
#          JIRA cloud server.  Once connection established, run
#          "XX" command to read in a .csv file for setting up a
#          JIRA card for release deployment (INT to PreProd to Prod)
########################################################################

class JSRC {
    static $cred = $null
    static [string]$credentialFile = "$($env:USERPROFILE)\.jiraSetupCred.txt"
    static [string]$servername = $null

    # Reset saved settings
    [void] JiraCardsClearSettings () {
      Remove-Item -LiteralPath [JSRC]::credentialFile
    }

    # Initialization routine (reads in settings file if exists, otherwise 
    #   sets up username, password (encrypted), and JIRA server)
    # $credentialFile contents:
    #   Line 0 = Username
    #   Line 1 = Encrypted password
    #   Line 2 = Server name
    JSRC () {
        [string]$username = ""
        $securePasswd = $null
    
        if (Test-Path -Path ([JSRC]::credentialFile) -PathType leaf) {
          $credFileContents = Get-Content ([JSRC]::credentialFile)
          if ($credFileContents.Length -ne 3) {
            Write-Error "Incorrect file line length.  Expect username, password, servername.  Length = '$($credFileContents.Length)'"
            Write-Error "Run JSRC-ResetSettings to clear settings file and then re-run this function."
            return
          }
          $securePasswd = ConvertTo-SecureString $credFileContents[1]
          [JSRC]::cred = New-Object System.Management.Automation.PSCredential($credFileContents[0], $securePasswd)
          [JSRC]::servername = $credFileContents[2]
        } else {
          [JSRC]::servername = Read-Host "Please enter Jira server (e.g. https://ivinci.atlassian.net)"
          [JSRC]::cred = Get-Credential 

          # Save username, encrypted password, and server
          [JSRC]::cred.UserName | Set-Content ([JSRC]::credentialFile)
          $securePasswd = ConvertFrom-SecureString -SecureString ([JSRC]::cred.Password)
          $securePasswd | Add-Content ([JSRC]::credentialFile)
          [JSRC]::servername | Add-Content ([JSRC]::credentialFile)
        }
        $this.OpenJiraConnection()
    }

    [void] OpenJiraConnection () {
        Set-JiraConfigServer -Server ([JSRC]::servername)
        New-JiraSession -Credential ([JSRC]::cred)
    }

    [void] CreateReleaseCards (
        [string]$summary,
        [string]$description,
        [string]$project,
        [string]$cardType,
        [string]$reporter,
        [string]$childFile
    ) {
        if ((Test-Path -Path $childFile -PathTYpe leaf) -ne $true) {
            Write-Error "childFile param '$childFile' is an invalid file"
            return
        }
        $childCSV = Import-Csv $childFile

        # Create the parent card first
        $parentResult = New-JiraIssue -IssueType $cardType -Project $project -Reporter $reporter -Summary $summary -Description $description `
            -Priority ($this.PriorityLookup("Must")) 
        if ($parentResult -eq $null) {
            Write-Error "Failed to create the parent card.  Aborting."
            return
        }
        Write-Host "Parent card: $($parentResult.Key)"
        # Update issue with assignee (not available in creation)
        Set-JiraIssue -Issue $parentResult.Key -Assignee $reporter

        # Create the children cards
        # NOTE: Ignore any "Won'ts", except a "Won't" that has a NULL Assignee -- those cards are separators and should be included and set to "Won't"
        for ($i=0; $i -lt $childCSV.Count; $i++) {
            if (($childCSV[$i].Priority -eq "Won't") -and ($childCSV[$i].Assignee -ne "")) {continue}
            $childResult = New-JiraIssue -IssueType $childCSV[$i].'Issue Type' -Project $project -Reporter $reporter -Summary $childCSV[$i].Summary `
                -Description $childCSV[$i].Description -Parent $parentResult.Key -Priority ($this.PriorityLookup($childCSV[$i].Priority)) 
            $childCSV[$i].'Issue Key' = $childResult.Key
        }

        # Create csv file to include new keys for each child
        $updatedFile = $childFile.Replace(".csv",".updated.csv")
        if ($updatedFile -eq $childFile) {
            $updatedFile = "$($updatedFile).updated.csv"
        }
        $childCSV | Export-Csv -LiteralPath $updatedFile
        Write-Host "Updated CSV file = '$updatedFile'"
    }

    [void] UpdateAssignees([string]$assigneeFile) {
        if ((Test-Path -PathType Leaf $assigneeFile) -ne $true) {
            Write-Error "'$assigneeFile' is an invalid file"
            return
        }
        $childCSV = Import-Csv $assigneeFile
        for ($i=0; $i -lt $childCSV.Count; $i++) {
            if (($childCSV[$i].Priority -eq "Won't") -or ($childCSV[$i].Assignee -eq "")) {continue}
            if ($childCSV[$i].Unassign -ne "") {
                Set-JiraIssue -Issue $childCSV[$i].'Issue Key' -Assignee "Unassigned"
            } else {
                Set-JiraIssue -Issue $childCSV[$i].'Issue Key' -Assignee $childCSV[$i].Assignee
            }
        }
    }

    [int] PriorityLookup ([string]$priorityName) {
        $result = -1
        # This is dependent on your unique implementation, this is our set of values
        # To find your set of values run the following in powershell (after connecting with PSJira):
        #    $meta = Get-JiraIssueCreateMetadata -Project "<your_project_name>" -IssueType "<your_desired_issue_type>"
        #    ($meta -match "Priority").AllowedValues | Select-Object -Property name, id
        switch ($priorityName) {
            "¡URGENT!" {$result = 10000}
            "Must" {$result = 2}
            "Should" {$result = 3}
            "Could" {$result = 4}
            "Won't" {$result = 5}
        }
        return $result
    }
    
    [void] CloseJiraConnection () {
        Remove-JiraSession
    }
}
        

Function JSRC-SetupReleaseCards(
        [parameter(Mandatory=$true)][string]$Summary,
        [parameter(Mandatory=$true)][string]$Description,
        [parameter(Mandatory=$true)][string]$ChildFilePath
) {
    $STARTTIME = Get-date

    $cardMaker = [JSRC]::new()
    $cardMaker.CreateReleaseCards($Summary, $Description, "RM", "Task", "gcattin", $ChildFilePath)
    $cardMaker.CloseJiraConnection()

    $ENDTIME = Get-Date
    Write-Host $($ENDTIME - $STARTTIME | Format-Table | Out-String)
}

Function JSRC-UpdateAssignees([string]$assigneeFile) {
    $STARTTIME = Get-date

    $cardMaker = [JSRC]::new()
    $cardMaker.UpdateAssignees($assigneeFile)
    $cardMaker.CloseJiraConnection()

    $ENDTIME = Get-Date
    Write-Host $($ENDTIME - $STARTTIME | Format-Table | Out-String)
}

Function JSRC-ResetSettings() {
    if (Test-Path -PathType Leaf ([JSRC]::credentialFile)) {
        Remove-Item -LiteralPath ([JSRC]::credentialFile)
    }
}