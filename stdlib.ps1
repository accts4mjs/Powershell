# This is a standard set of functions for simplifying scripting in Powershell

# GLOBAL VARS - controls settings in functions below
$LOGLEVEL = 0
$LOGFILE = $null

Function ASSERT([string]$message, [Parameter(Mandatory=$true, 
    Position=0)][bool]$assert) {
  try {
    if (! $assert) {
      if ($message -ne '') {
        throw $message
      } else {
        throw "Unknown Error"
      }
    }
  } catch {
    Write-Error $_
  }
}

Function TimeStamp() {
  Get-Date -UFormat "%Y%m%d%H%M%S" | Write-Output
}

Function MilliTimeStamp() {
  Get-Date -Format FileDateTime | Write-Output
}

Function LOG1([string]$message) {
  if ($LOGLEVEL -lt 1) {return}
  if ($LOGFILE -eq $null) {
    Write-Debug "LOG1:$(MilliTimeStamp):$message"
  } else {
    Write-Debug "LOG1:$(MilliTimeStamp):$message" > $LOGFILE
  }
}
  
Function LOG2([string]$message) {
  if ($LOGLEVEL -lt 2) {return}
  if ($LOGFILE -eq $null) {
    Write-Debug "LOG2:$(MilliTimeStamp):$message"
  } else {
    Write-Debug "LOG2:$(MilliTimeStamp):$message" > $LOGFILE
  }
}

Function LOG-EnableFile() {
  $LOGFILE = "log." + ($MyInvocation.PSCommandPath).split("\\")[-1] + "." + $(TimeStamp)
  Write-Debug "$LOGFILE"
}

Function LOG-DisableFile() {
  $LOGFILE = $null
}
