# Include standard functions (error handling, logging, debugging, etc)
. $env:PSBIN\stdlib.ps1
$LOGLEVEL = 0
$DebugPreference = "Continue"
LOG-EnableFile

#######################################################################
# Classes
#######################################################################

class FileInfo {
  static [int]$uid_counter = 0
  hidden [int]$uid
  [string]$filename
  [string]$fullname
  [string]$dirname
  $fileNameMatchList = $null
  [bool]$duplicate = $false
  [string]$filehash
  [int]$size

  FileInfo($fileObject) {
    LOG1("FileInfo::FileInfo")
    try {
      Test-Path $fileObject
    } catch {
      LOG2("$($fileObject.fullname)")
    }
    $this.uid = [FileInfo]::uid_counter++
    $this.filename = $fileObject.Name
    $this.fullname = $fileObject.FullName
    $this.dirname = $fileObject.DirectoryName
    try {
      $this.filehash = (Get-FileHash $fileObject -ErrorAction Stop).hash      
    } catch {
      LOG2("$($fileObject.FullName)")
    }
    $this.size = $fileObject.Length
    LOG2($this | Out-String)
  }

  [int]GetUid() {
    return $this.uid
  }

  static [void]ResetUidCounter() {
    [FileInfo]::uid_counter = 0
  }

  [void]AddMatch($fileObject) {
    LOG1("FileInfo::AddMatch")
    if ($this.fileNameMatchList -eq $null) {
      # First match made, create the list and add the name of the calling object (before adding the passed in object name below)
      $this.fileNameMatchList = New-Object 'System.Collections.Generic.List[string]'
      $this.fileNameMatchList.Add($this.fullname)
    }
    $this.fileNameMatchList.Add($fileObject.fullname)
  }
}

Class FileInfoList {
  $fileInfoHash = @{}

  [void]ToCSV([string]$outputfile) {
    LOG1("FileInfoList::ToCSV")
    # Note: csv files need to be encoded in utf8 or Excel treats them as rows of strings
    Write-Output """FileName"",""Fullpath"",""Length"",""Hash""" | Out-File $outputfile -Encoding utf8
    $csvOutput = foreach ($k in $this.fileInfoHash.Keys) {
      foreach ($f in $this.fileInfoHash[$k]) {
        if (-not $f.duplicate) {
          foreach ($fname in $f.fileNameMatchList) {
            Write-Output """$($f.filename)"",""$fname"",""$($f.size)"",""$($f.filehash)"""
          }
        }
      }
    }
    $csvOutput | Out-File $outputfile -Append -Encoding utf8
  }

  [void]Add([FileInfo]$fileObj) {
    LOG1("FileInfoList::Add")
    if ($this.fileInfoHash[$fileObj.filename] -eq $null) {
      # New entry, create the list and add the object
      $this.fileInfoHash[$fileObj.filename] = New-Object 'System.Collections.Generic.List[FileInfo]'
      ($this.fileInfoHash[$fileObj.filename]).Add($fileObj)
    } else {
      # Possible match (hash already exists). Iterate through list to 
      # check for a match before the add (otherwise will find self in
      # list and mark as match).  Once a match is found, stop searching.
      foreach ($currFileObj in $this.fileInfoHash[$fileObj.filename]) {
        if ($currFileObj.filehash -eq $fileObj.filehash -and -not $currFileObj.duplicate) {
          $currFileObj.AddMatch($fileObj)
          $fileObj.duplicate = $true
          break
        }
      }
      # Add the passed in object (having already checked for dups, still need to add it)
      ($this.fileInfoHash[$fileObj.filename]).Add($fileObj)
    }
  }

  [void]FindDuplicateFiles([string[]]$path, [string]$include) {
    LOG1("FileInfoList::FindDuplicateFiles")
    foreach ($fileObj in Get-ChildItem -Path $path -Force -Recurse -Include $include) {
      LOG2("ChildItem = " + $fileObj.FullName)
      try {
        if ((Get-Item $fileObj -ErrorAction Stop).PSIsContainer) {continue}
      } catch {
        LOG2("$($fileObj.fullname)")
      }
      $this.Add([FileInfo]::new($fileObj))
    }
    LOG1("Number of files scanned: $([FileInfo]::uid_counter)")
  }
}


######################################################################
# Functions
######################################################################

Function Build-DuplicateFileList($include = "*", $outpath = ".\", $fileprefix = "DuplicateFileList",
  $filesuffix = "csv", [Parameter(Mandatory = $true, Position = 0)][string[]]$path) {
  
  LOG1("$($MyInvocation.MyCommand.Name)")
  $STARTTIME = Get-date

  $outputfile = "$outpath\$fileprefix.$(Get-date -UFormat ""%Y%m%H%M%S"").$filesuffix"
  [FileInfo]::ResetUidCounter()
  $dupfiles = [FileInfoList]::new()
  $dupfiles.FindDuplicateFiles($path, $include)
  $dupfiles.ToCSV($outputfile)

  $ENDTIME = Get-Date
  Write-Host $($ENDTIME - $STARTTIME | Format-Table | Out-String)
}