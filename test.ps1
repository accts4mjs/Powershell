# Include standard functions (error handling, logging, debugging, etc)
. $env:PSBIN\stdlib.ps1
$LOGLEVEL = 0
LOG-Enable
######################################################################
# Sample Function
######################################################################

# PowerShell function example script: Calculate batting average
# Author: Guy Thomas
Function Get-BatAvg {
[cmdletbinding()]
Param (
[string]$Name,
[int]$Hits, [int]$AtBats
   )
# End of Parameters
Process {
"Enter Name Hits AtBats..."
$Avg = [int]($Hits / $AtBats*100)/100
if($Avg -gt 1)
      {
"$Name's cricket average = $Avg : $Hits Runs, $AtBats dismissals"
      } # End of If
Else {
"$Name's baseball average = $Avg : $Hits Hits, $AtBats AtBats"
         } # End of Else.
      } # End of Process
}

######################################################################
# Test Args and Parameters
######################################################################

Function Test-Args {
  Write-Output "#Args = $($args.count)"
  for ($i=0; $i -lt $args.count; $i++) {
    Write-Output "args[$i] = '$($args[$i])'"
  }
}

Function Test-Params($a = "default", [switch]$b) {
  Write-Output "#Args = $($args.count)"
  for ($i=0; $i -lt $args.count; $i++) {
    Write-Output "args[$i] = '$($args[$i])'"
  }
  Write-Output "-a = '$a' -b = '$b'"
}

Function Test-OptionalParams($a = "default", [switch]$b, $c,
    [Parameter(Mandatory = $true, Position = 0)]$d) {
  Write-Output "#Args = $($args.count)"
  for ($i=0; $i -lt $args.count; $i++) {
    Write-Output "args[$i] = '$($args[$i])'"
  }
  Write-Output "-a = '$a' -b = '$b'"

}

######################################################################
# Test classes and object creation
######################################################################

class TestClass {
  [string]$name
  [int]$size
  [bool]$valid
}

Function Test-CustomClass {
  $testObj = [TestClass]::new()

  $testObj # Print out values

  $testObj.name = "Hello, world!"
  $testObj.size = 42
  $testObj.valid = $true

  $testObj # Print out values
}

class TestClassConstructor {
  [string]$name
  [int]$size
  [bool]$valid
  hidden [int]$uid
  static [int]$uid_counter = 0

  TestClassConstructor(
    [string]$_name,
    [int]$_size
  ) {
    $this.name = $_name
    $this.size = $_size
    $this.valid = $false
    $this.uid = [TestClassConstructor]::uid_counter++;
  }
}

Function Test-CustomClassConstructor {
  $testObj = [TestClassConstructor]::new("MyClass", 7)

  $testObj # Print out values

  $testObj.name = "Hello, world!"
  $testObj.size = 42
  $testObj.valid = $true

  $testObj # Print out values
}

class TestFileInfo {
  static [int]$uid_counter = 0
  hidden [int]$uid
  [string]$filename
  [string]$fullname
  [string]$dirname
  $fileNameMatchList = $null
  [bool]$duplicate = $false
  [string]$filehash
  [int]$size

  TestFileInfo($fileObject) {
    LOG1("TestFileInfo")
    try {
      Test-Path $fileObject
    } catch {
      LOG2("$($fileObject.fullname)")
    }
    $this.uid = [TestFileInfo]::uid_counter++
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
    [TestFileInfo]::uid_counter = 0
  }

  [void]AddMatch($fileObject) {
    if ($this.fileNameMatchList -eq $null) {
      $this.fileNameMatchList = New-Object 'System.Collections.Generic.List[string]'
      # Need to add the original match fullname the first time we find a match
      $this.fileNameMatchList.Add($this.fullname)
    }
    $this.fileNameMatchList.Add($fileObject.fullname)
  }
}

Class TestFileInfoList {
  $fileInfoHash = @{}

  ToCSV() {
    throw "Not implemented yet"
  }

  [void]Add([TestFileInfo]$fileObj) {
    LOG1("TestFileInfoList::Add")
    if ($this.fileInfoHash[$fileObj.filename] -eq $null) {
      # New entry
      $this.fileInfoHash[$fileObj.filename] = New-Object 'System.Collections.Generic.List[TestFileInfo]'
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
      ($this.fileInfoHash[$fileObj.filename]).Add($fileObj)
    }
  }
}




######################################################################
# Dir and file objects
######################################################################

# Note: if mandatory param not provided it will prompt for it in the CLI
Function Test-FindFiles($include = "*", [Parameter(Mandatory = $true,
    Position = 0)]$path) {
  Write-Output "include = '$include' path = '$path'"
  Get-ChildItem -Path $path -Force -Recurse -Include $include
}

Function Test-BuildFileList($include = "*", [Parameter(Mandatory = $true,
  Position = 0)]$path) {

  $fileHash = @{}

  foreach ($fileObj in Get-ChildItem -Path $path -Force -Recurse -Include $include) {
    if ((Get-Item $fileObj).PSIsContainer) {continue}
    $fileHash = [TestFileInfo]::new($fileObj)
    return
  }
}

Function Test-BuildFileInfoList($include = "*", $outpath = ".\", $fileprefix = "TestBFIL", [Parameter(Mandatory = $true,
  Position = 0)]$path) {
  LOG1("Test-BuildFileInfoList")
  $STARTTIME = Get-date

  $outfile = "$outpath\$fileprefix.$(Get-date -UFormat ""%Y%m%H%M%S"")"
  $fileInfoList = [TestFileInfoList]::new()
  [TestFileInfo]::ResetUidCounter()

  foreach ($fileObj in Get-ChildItem -Path $path -Force -Recurse -Include $include -ErrorAction SilentlyContinue) {
    LOG2("ChildItem = " + $fileObj.FullName)
    try {
      if ((Get-Item $fileObj -ErrorAction Stop).PSIsContainer) {continue}
    } catch {
      LOG2("$($fileObj.fullname)")
    }
    $fileInfoList.Add([TestFileInfo]::new($fileObj))
  }
  
  Write-Output "Number of files scanned: $([TestFileInfo]::uid_counter)"
  Write-Output """FileName"",""Fullpath"",""Length"",""Hash""" | Out-File ".\csvout.csv" -Encoding utf8
  #Write-Output "FileName,Fullpath,Length,Hash" | Export-Csv -Path ".\csv.csv"
  $csvOutput = foreach ($k in $fileInfoList.fileInfoHash.Keys) {
    foreach ($f in $fileInfoList.fileInfoHash[$k]) {
      if (-not $f.duplicate) {
        foreach ($fname in $f.fileNameMatchList) {
          Write-Output """$($f.filename)"",""$fname"",""$($f.size)"",""$($f.filehash)"""
        }
      }
    }
  }
  # Write-Output $csvOutput
  $csvOutput | Out-File ".\csvout.csv" -Append -Encoding utf8
  #$csvOutput | Export-Csv -Path ".\csv.csv" -Append -Force
  $ENDTIME = Get-Date
  $ENDTIME - $STARTTIME | Format-Table
}

Function Test-Logfile() {
  SetLogfile
}