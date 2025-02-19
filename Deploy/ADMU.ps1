# Check runningaslocaladmin
if (([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) -eq $false)
{
    Write-Host 'ADMU must be ran as a local administrator..please correct & try again'
    Read-Host -Prompt "Press Enter to exit"
    exit
}
# Load functions
#region Functions
function Show-Result
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $domainUser,
        [Parameter()]
        [System.Object]
        $admuTrackerInput,
        [Parameter()]
        [string[]]
        $FixedErrors,
        [Parameter()]
        [string]
        $profilePath,
        [Parameter()]
        [string]
        $localUser,
        [Parameter()]
        [string]
        $logPath,
        [Parameter(Mandatory = $true)]
        [bool]
        $success
    )
    process
    {
        # process tasks
        if ($success)
        {
            $message = "ADMU completed successfully:`n"
            $message += "$domainUser was migrated to $localUser.`n"
            $message += "$($localUser)'s Account Details:`n"
            $message += "Profile Path: $profilePath`n"
        }
        else
        {
            $message = "ADMU did not complete sucessfully:`n"
            $message = "$domainUser was not migrated.`n"
            $failures = $($admuTrackerInput.Keys | Where-Object { $admuTrackerInput[$_].fail -eq $true } )
            if ($failures)
            {
                $message += "`nEncounted errors on the following steps:`n"
                foreach ($item in $failures)
                {
                    $message += "$item`n"
                }
            }
            if ($FixedErrors)
            {
                $message += "`nChanges in the following steps were reverted:`n"
                foreach ($item in $FixedErrors)
                {
                    $message += "$item`n"
                }
            }
            #TODO: verbose messaging for errors
            # foreach ($item in $failures)
            # {
            #     $message += "-------------------------------------------------------- `n"
            #     $message += "Step Failure Reason: $($admuTrackerInput[$item].remedy) `n"
            #     $message += "Step Description: $($admuTrackerInput[$item].description) `n"
            #     $message += "-------------------------------------------------------- `n"
            # }
            # foreach ($item in $FixedErrors)
            # {
            #     $message += "-------------------------------------------------------- `n"
            #     $message += "Step: $item | was reverted to its orgional state`n"
            #     $message += "-------------------------------------------------------- `n"
            # }
        }
        $message += "`nClick 'OK' to open the ADMU log"
        $wshell = New-Object -ComObject Wscript.Shell
        $var = $wshell.Popup("$message", 0, "ADMU Status", 0x1 + 0x40)
        if ($var -eq 1)
        {
            notepad $logPath
        }
        # return $var
    }
}
function Test-RegistryValueMatch
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]$Path,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]$Value,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]$stringmatch
    )
    $ErrorActionPreference = "SilentlyContinue"
    $regvalue = Get-ItemPropertyValue -Path $Path -Name $Value
    $ErrorActionPreference = "Continue"
    $out = 'Value For ' + $Value + ' Is ' + $1 + ' On ' + $Path
    if ([string]::IsNullOrEmpty($regvalue))
    {
        write-host 'KEY DOESNT EXIST OR IS EMPTY'
        return $false
    }
    else
    {
        if ($regvalue -match ($stringmatch))
        {
            Write-Host $out
            return $true
        }
        else
        {
            Write-Host $out
            return $false
        }
    }
}
function BindUsernameToJCSystem
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][ValidateLength(40, 40)][string]$JcApiKey,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][string]$JumpCloudUserName
    )
    Begin
    {
        $config = get-content "$WindowsDrive\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf"
        $regex = 'systemKey\":\"(\w+)\"'
        $systemKey = [regex]::Match($config, $regex).Groups[1].Value
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        If (!$systemKey)
        {
            Write-ToLog -Message:("Could not find systemKey, aborting bind step") -Level:('Warn')
        }
    }
    Process
    {
        # Get UserID from JumpCloud Console
        $ret, $id = Test-JumpCloudUsername -JumpCloudApiKey $JcApiKey -Username $JumpCloudUserName
        if ($ret -And $id)
        {
            $Headers = @{
                'Accept'       = 'application/json';
                'Content-Type' = 'application/json';
                'x-api-key'    = $JcApiKey;
            }
            $Form = @{
                'op'   = 'add';
                'type' = 'system';
                'id'   = "$systemKey"
            } | ConvertTo-Json
            Try
            {
                $Response = Invoke-WebRequest -Method 'Post' -Uri "https://console.jumpcloud.com/api/v2/users/$id/associations" -Headers $Headers -Body $Form -UseBasicParsing
                $StatusCode = $Response.StatusCode
            }
            catch
            {
                $StatusCode = $_.Exception.Response.StatusCode.value__
                Write-ToLog -Message:("Could not bind user to system") -Level:('Warn')
            }
        }
        else
        {
            Write-ToLog -Message:("JumpCloud Username did not exist in JumpCloud Directory") -Level:('Warn')
        }
    }
    End
    {
        # Associations post should return 204 success no content
        if ($StatusCode -eq 204)
        {
            return $true
        }
        else
        {
            return $false
        }
    }
}
function DenyInteractiveLogonRight
{
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $SID
    )
    process
    {
        # Add migrating user to deny logon rights
        $secpolFile = "C:\Windows\temp\ur_orig.inf"
        if (Test-Path $secpolFile)
        {
            Remove-Item $secpolFile -Force
        }
        secedit /export /areas USER_RIGHTS /cfg C:\Windows\temp\ur_orig.inf
        $secpol = (Get-Content $secpolFile)
        $regvaluestring = $secpol | Where-Object { $_ -like "*SeDenyInteractiveLogonRight*" }
        $regvaluestringID = [array]::IndexOf($secpol, $regvaluestring)
        $oldvalue = (($secpol | Select-String -Pattern 'SeDenyInteractiveLogonRight' | Out-String).trim()).substring(30)
        $newvalue = ('*' + $SID + ',' + $oldvalue.trim())
        $secpol[$regvaluestringID] = 'SeDenyInteractiveLogonRight = ' + $newvalue
        $secpol | out-file $windowsDrive\Windows\temp\ur_new.inf -force
        secedit /configure /db secedit.sdb /cfg $windowsDrive\Windows\temp\ur_new.inf /areas USER_RIGHTS
    }
}
function Register-NativeMethod
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$dll,
        # Param2 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]
        $methodSignature
    )
    process
    {
        $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
    }
}
function Add-NativeMethod
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param($typeName = 'NativeMethods')
    process
    {
        $nativeMethodsCode = $script:nativeMethods | ForEach-Object { "
          [DllImport(`"$($_.Dll)`")]
          public static extern $($_.Signature);
      " }
        Add-Type @"
          using System;
          using System.Text;
          using System.Runtime.InteropServices;
          public static class $typeName {
              $nativeMethodsCode
          }
"@
    }
}
function New-LocalUserProfile
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$UserName
    )
    process
    {
        $methodname = 'UserEnvCP2'
        $script:nativeMethods = @();
        if (-not ([System.Management.Automation.PSTypeName]$methodname).Type)
        {
            Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
           [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
           [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";
            Add-NativeMethod -typeName $methodname;
        }
        $sb = new-object System.Text.StringBuilder(260);
        $pathLen = $sb.Capacity;
        Write-ToLog "Creating user profile for $UserName";
        if ($UserName -eq $env:computername)
        {
            Write-ToLog "$UserName Matches ComputerName";
            $objUser = New-Object System.Security.Principal.NTAccount("$env:computername\$UserName")
        }
        else
        {
            $objUser = New-Object System.Security.Principal.NTAccount($UserName)
        }
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $SID = $strSID.Value
        try
        {
            $result = [UserEnvCP2]::CreateProfile($SID, $Username, $sb, $pathLen)
            if ($result -eq '-2147024713')
            {
                $status = "$userName is an existing account"
                Write-ToLog "$username creation result: $result"
            }
            elseif ($result -eq '-2147024809')
            {
                $status = "$username Not Found"
                Write-ToLog "$username Creation Result: $result"
            }
            elseif ($result -eq 0)
            {
                $status = "$username Profile has been created"
                Write-ToLog "$username Creation Result: $result"
            }
            else
            {
                $status = "$UserName unknown return result: $result"
            }
        }
        catch
        {
            Write-Error $_.Exception.Message;
            # break;
        }
        # $status
    }
    end
    {
        return $SID
    }
}
function Remove-LocalUserProfile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UserName
    )
    Begin
    {
        # Validate that the user was just created by the ADMU
        $removeUser = $false
        $users = Get-LocalUser
        foreach ($user in $users)
        {
            # we only want to remove users with description "Created By JumpCloud ADMU"
            if ( $user.name -match $UserName -And $user.description -eq "Created By JumpCloud ADMU" )
            {
                $UserSid = Get-SID -User $UserName
                $UserPath = Get-ProfileImagePath -UserSid $UserSid
                # Set RemoveUser bool to true
                $removeUser = $true
            }
        }
        if (!$removeUser)
        {
            throw "Username match not found, not reversing"
        }
    }
    Process
    {
        # Remove the profile
        if ($removeUser)
        {
            # Remove the User
            Remove-LocalUser -Name $UserName
            # Remove the User Profile
            if (Test-Path -Path $UserPath)
            {
                $Group = New-Object System.Security.Principal.NTAccount("Builtin", "Administrators")
                $ACL = Get-ACL $UserPath
                $ACL.SetOwner($Group)
                Get-ChildItem $UserPath -Recurse -Force -errorAction SilentlyContinue | ForEach-Object {
                    Try
                    {
                        Set-ACL -AclObject $ACL -Path $_.fullname -errorAction SilentlyContinue
                    }
                    catch [System.Management.Automation.ItemNotFoundException]
                    {
                        Write-Verbose 'ItemNotFound : $_'
                    }
                }
                # icacls $($UserPath) /grant administrators:F /T
                # takeown /f $($UserPath) /r /d y
                Remove-Item -Path $($UserPath) -Force -Recurse #-ErrorAction SilentlyContinue
            }
            # Remove the User SID
            # TODO: if the profile SID is loaded in registry skip this and note in log
            # Match the user SID
            $matchedKey = get-childitem -path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' | Where-Object { $_.Name -match $UserSid }
            # Set the Matched Key Path to PSPath so PowerShell can use the path
            $matchedKeyPath = $($matchedKey.Name) -replace "HKEY_LOCAL_MACHINE", "HKLM:"
            # Remove the UserSid Key from the ProfileList
            Remove-Item -Path "$matchedKeyPath" -Recurse
        }
    }
    End
    {
        # Output some info
        Write-ToLog -message:("$UserName's account, profile and Registry Key SID were removed")
    }
}
# Reg Functions adapted from:
# https://social.technet.microsoft.com/Forums/windows/en-US/9f517a39-8dc8-49d3-82b3-96671e2b6f45/powershell-set-registry-key-owner-to-the-system-user-throws-error?forum=winserverpowershell
function Set-ValueToKey([Microsoft.Win32.RegistryHive]$registryRoot, [string]$keyPath, [string]$name, [System.Object]$value, [Microsoft.Win32.RegistryValueKind]$regValueKind)
{
    $regRights = [System.Security.AccessControl.RegistryRights]::SetValue
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $Key = [Microsoft.Win32.Registry]::$registryRoot.OpenSubKey($keyPath, $permCheck, $regRights)
    Write-ToLog -Message:("Setting value with properties [name:$name, value:$value, value type:$regValueKind]")
    $Key.SetValue($name, $value, $regValueKind)
    $key.Close()
}
function New-RegKey([string]$keyPath, [Microsoft.Win32.RegistryHive]$registryRoot)
{
    $Key = [Microsoft.Win32.Registry]::$registryRoot.CreateSubKey($keyPath)
    Write-ToLog -Message:("Setting key at [KeyPath:$keyPath]")
    $key.Close()
}
#username To SID Function
function Get-SID ([string]$User)
{
    $objUser = New-Object System.Security.Principal.NTAccount($User)
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
    $strSID.Value
}
function Set-UserRegistryLoadState
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Unload", "Load")]
        [System.String]$op,
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [System.String]$ProfilePath,
        # User Security Identifier
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
        [System.String]$UserSid
    )
    process
    {
        switch ($op)
        {
            "Load"
            {
                Start-Sleep -Seconds 1
                $results = REG LOAD HKU\$($UserSid)_admu "$ProfilePath\NTUSER.DAT.BAK" *>&1
                if ($?)
                {
                    Write-ToLog -Message:('Load Profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
                }
                else
                {
                    Write-ToLog -Message:('Cound not load profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
                }
                Start-Sleep -Seconds 1
                $results = REG LOAD HKU\"$($UserSid)_Classes_admu" "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" *>&1
                if ($?)
                {
                    Write-ToLog -Message:('Load Profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
                }
                else
                {
                    Write-ToLog -Message:('Cound not load profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
                }
            }
            "Unload"
            {
                [gc]::collect()
                Start-Sleep -Seconds 1
                $results = REG UNLOAD HKU\$($UserSid)_admu *>&1
                if ($?)
                {
                    Write-ToLog -Message:('Unloaded Profile: ' + "$ProfilePath\NTUSER.DAT.bak")
                }
                else
                {
                    Write-ToLog -Message:('Could not unload profile: ' + "$ProfilePath\NTUSER.DAT.bak")
                }
                Start-Sleep -Seconds 1
                $results = REG UNLOAD HKU\$($UserSid)_Classes_admu *>&1
                if ($?)
                {
                    Write-ToLog -Message:('Unloaded Profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
                }
                else
                {
                    Write-ToLog -Message:('Could not unload profile: ' + "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak")
                }
            }
        }
    }
}
Function Test-UserRegistryLoadState
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [System.String]$ProfilePath,
        # User Security Identifier
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
        [System.String]$UserSid
    )
    begin
    {
        $results = REG QUERY HKU *>&1
        # Tests to check that the reg items are not loaded
        If ($results -match $UserSid)
        {
            Write-ToLog "REG Keys are loaded, attempting to unload"
            Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
        }
    }
    process
    {
        # Load New User Profile Registry Keys
        try
        {
            Set-UserRegistryLoadState -op "Load" -ProfilePath $ProfilePath -UserSid $UserSid
        }
        catch
        {
            Write-Error "Could Not Load"
        }
        # Load Selected User Profile Keys
        # Unload "Selected" and "NewUser"
        try
        {
            Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
        }
        catch
        {
            Write-Error "Could Not Unload"
        }
    }
    end
    {
        $results = REG QUERY HKU *>&1
        # Tests to check that the reg items are not loaded
        If ($results -match $UserSid)
        {
            Write-ToLog "REG Keys are loaded, attempting to unload"
            Set-UserRegistryLoadState -op "Unload" -ProfilePath $ProfilePath -UserSid $UserSid
        }
        $results = REG QUERY HKU *>&1
        # Tests to check that the reg items are not loaded
        If ($results -match $UserSid)
        {
            Write-ToLog "REG Keys are loaded at the end of testing, exiting..." -level Warn
            throw "REG Keys are loaded at the end of testing, exiting..."
        }
    }
}
Function Backup-RegistryHive
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $profileImagePath
    )
    try
    {
        Copy-Item -Path "$profileImagePath\NTUSER.DAT" -Destination "$profileImagePath\NTUSER.DAT.BAK" -ErrorAction Stop
        Copy-Item -Path "$profileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Destination "$profileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -ErrorAction Stop
    }
    catch
    {
        Write-ToLog -Message("Could Not Backup Registry Hives in $($profileImagePath): Exiting...")
        Write-ToLog -Message($_.Exception.Message)
        throw "Could Not Backup Registry Hives in $($profileImagePath): Exiting..."
    }
}
Function Get-ProfileImagePath
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^S-\d-\d+-(\d+-){1,14}\d+$")]
        [System.String]
        $UserSid
    )
    $profileImagePath = Get-ItemPropertyValue -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $UserSid) -Name 'ProfileImagePath'
    if ([System.String]::IsNullOrEmpty($profileImagePath))
    {
        Write-ToLog -Message("Could not get the profile path for $UserSid exiting...") -level Warn
        throw "Could not get the profile path for $UserSid exiting..."
    }
    else
    {
        return $profileImagePath
    }
}
Function Get-WindowsDrive
{
    $drive = (wmic OS GET SystemDrive /VALUE)
    $drive = [regex]::Match($drive, 'SystemDrive=(.\:)').Groups[1].Value
    return $drive
}
#Logging function
<#
  .Synopsis
     Write-ToLog writes a message to a specified log file with the current time stamp.
  .DESCRIPTION
     The Write-ToLog function is designed to add logging capability to other scripts.
     In addition to writing output and/or verbose you can write to a log file for
     later debugging.
  .NOTES
     Created by: Jason Wasser @wasserja
     Modified: 11/24/2015 09:30:19 AM
  .PARAMETER Message
     Message is the content that you wish to add to the log file.
  .PARAMETER Path
     The path to the log file to which you would like to write. By default the function will
     create the path and file if it does not exist.
  .PARAMETER Level
     Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
  .EXAMPLE
     Write-ToLog -Message 'Log message'
     Writes the message to c:\Logs\PowerShellLog.log.
  .EXAMPLE
     Write-ToLog -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
     Writes the content to the specified log file and creates the path and file specified.
  .EXAMPLE
     Write-ToLog -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
     Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
  .LINK
     https://gallery.technet.microsoft.com/scriptcenter/Write-ToLog-PowerShell-999c32d0
  #>
Function Write-ToLog
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message
        , [Parameter(Mandatory = $false)][Alias('LogPath')][string]$Path = "$(Get-WindowsDrive)\Windows\Temp\jcAdmu.log"
        , [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info")][string]$Level = "Info"
    )
    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        If (!(Test-Path $Path))
        {
            Write-Verbose "Creating $Path."
            New-Item $Path -Force -ItemType File
        }
        Else
        {
            # Nothing to see here yet.
        }
        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Write message to error, warning, or verbose pipeline and specify $LevelText
        Switch ($Level)
        {
            'Error'
            {
                Write-Error $Message
                $LevelText = 'ERROR:'
            }
            'Warn'
            {
                Write-Warning $Message
                $LevelText = 'WARNING:'
            }
            'Info'
            {
                Write-Verbose $Message
                $LevelText = 'INFO:'
            }
        }
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}
Function Remove-ItemIfExist
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][String[]]$Path
        , [Switch]$Recurse
    )
    Process
    {
        Try
        {
            If (Test-Path -Path:($Path))
            {
                Remove-Item -Path:($Path) -Recurse:($Recurse)
            }
        }
        Catch
        {
            Write-ToLog -Message ('Removal Of Temp Files & Folders Failed') -Level Warn
        }
    }
}
#Check if program is on system
function Test-ProgramInstalled
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $programName
    )
    process
    {
        if ($programName)
        {
            $installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -match $programName })
            $installed32 = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -match $programName })
        }
        if ((-not [System.String]::IsNullOrEmpty($installed)) -or (-not [System.String]::IsNullOrEmpty($installed32)))
        {
            return $true
        }
        else
        {
            return $false
        }
    }
}
# Check reg for program uninstall string and silently uninstall
function Uninstall-Program($programName)
{
    $Ver = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty |
    Where-Object { $_.DisplayName -match $programName } |
    Select-Object -Property DisplayName, UninstallString
    ForEach ($ver in $Ver)
    {
        If ($ver.UninstallString -and $ver.DisplayName -match 'Jumpcloud')
        {
            $uninst = $ver.UninstallString
            & cmd /C $uninst /Silent | Out-Null
        } If ($ver.UninstallString -and $ver.DisplayName -match 'AWS Command Line Interface')
        {
            $uninst = $ver.UninstallString
            & cmd /c $uninst /S | Out-Null
        }
        else
        {
            $uninst = $ver.UninstallString
            & cmd /c $uninst /q /norestart | Out-Null
        }
    }
}
#Start process and wait then close after 5mins
Function Start-NewProcess([string]$pfile, [string]$arguments, [int32]$Timeout = 300000)
{
    $p = New-Object System.Diagnostics.Process;
    $p.StartInfo.FileName = $pfile;
    $p.StartInfo.Arguments = $arguments
    [void]$p.Start();
    If (! $p.WaitForExit($Timeout))
    {
        Write-ToLog -Message "Windows ADK Setup did not complete after 5mins";
        Get-Process | Where-Object { $_.Name -like "adksetup*" } | Stop-Process
    }
}
#Validation functions
Function Test-IsNotEmpty ([System.String] $field)
{
    If (([System.String]::IsNullOrEmpty($field)))
    {
        Return $true
    }
    Else
    {
        Return $false
    }
}
Function Test-Is40chars ([System.String] $field)
{
    If ($field.Length -eq 40)
    {
        Return $true
    }
    Else
    {
        Return $false
    }
}
Function Test-HasNoSpace ([System.String] $field)
{
    If ($field -like "* *")
    {
        Return $false
    }
    Else
    {
        Return $true
    }
}
function Test-Localusername
{
    [CmdletBinding()]
    param (
        [system.array] $field
    )
    begin
    {
        $win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
        $users = $win32UserProfiles | Select-Object -ExpandProperty "SID" | Convert-Sid
        $localusers = new-object system.collections.arraylist
        foreach ($username in $users)
        {
            $domain = ($username -split '\\')[0]
            if ($domain -match $env:computername)
            {
                $localusertrim = $username -creplace '^[^\\]*\\', ''
                $localusers.Add($localusertrim) | Out-Null
            }
        }
    }
    process
    {
        if ($localusers -eq $field)
        {
            Return $true
        }
        else
        {
            Return $false
        }
    }
    end
    {
    }
}
function Test-Domainusername
{
    [CmdletBinding()]
    param (
        [system.array] $field
    )
    begin
    {
        $win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
        $users = $win32UserProfiles | Select-Object -ExpandProperty "SID" | Convert-Sid
        $domainusers = new-object system.collections.arraylist
        foreach ($username in $users)
        {
            if ($username -match (Get-NetBiosName) -or ($username -match 'AZUREAD'))
            {
                $domainusertrim = $username -creplace '^[^\\]*\\', ''
                $domainusers.Add($domainusertrim) | Out-Null
            }
        }
    }
    process
    {
        if ($domainusers -eq $field)
        {
            Return $true
        }
        else
        {
            Return $false
        }
    }
    end
    {
    }
}
function Test-JumpCloudUsername
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    [OutputType([System.Object[]])]
    param (
        [Parameter()]
        [System.String]
        $JumpCloudApiKey,
        [Parameter()]
        [System.String]
        $Username,
        [Parameter()]
        [System.Boolean]
        $prompt = $false
    )
    Begin
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Headers = @{
            'Accept'       = 'application/json';
            'Content-Type' = 'application/json';
            'x-api-key'    = $JumpCloudApiKey;
        }
        $Form = @{
            'filter' = "username:eq:$($Username)"
            "fields" = "username"
        }
        $Body = $Form | ConvertTo-Json
    }
    Process
    {
        Try
        {
            # Write-ToLog "Searching JC for: $Username"
            $Response = Invoke-WebRequest -Method 'Post' -Uri "https://console.jumpcloud.com/api/search/systemusers" -Headers $Headers -Body $Body -UseBasicParsing
            $Results = $Response.Content | ConvertFrom-Json
            $StatusCode = $Response.StatusCode
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
    End
    {
        # Search User should return 200 success
        If ($StatusCode -ne 200)
        {
            Return $false, $null
        }
        If ($Results.totalCount -eq 1 -and $($Results.results[0].username) -eq $Username)
        {
            # write-host $Results.results[0]._id
            return $true, $Results.results[0]._id
        }
        else
        {
            if ($prompt)
            {
                $message += "$Username is not a valid JumpCloud User`nPlease enter a valid JumpCloud Username`nUsernames are case sensitive"
                $wshell = New-Object -ComObject Wscript.Shell
                $var = $wshell.Popup("$message", 0, "ADMU Status", 0x0 + 0x40)
            }
            Return $false, $null
        }
    }
}
Function Install-JumpCloudAgent(
    [System.String]$msvc2013x64Link
    , [System.String]$msvc2013Path
    , [System.String]$msvc2013x64File
    , [System.String]$msvc2013x64Install
    , [System.String]$msvc2013x86Link
    , [System.String]$msvc2013x86File
    , [System.String]$msvc2013x86Install
    , [System.String]$AGENT_INSTALLER_URL
    , [System.String]$AGENT_INSTALLER_PATH
    , [System.String]$AGENT_PATH
    , [System.String]$AGENT_BINARY_NAME
    , [System.String]$JumpCloudConnectKey
)
{
    If (!(Test-ProgramInstalled("Microsoft Visual C\+\+ 2013 x64")))
    {
        Write-ToLog -Message:('Downloading & Installing JCAgent prereq Visual C++ 2013 x64')
        (New-Object System.Net.WebClient).DownloadFile("${msvc2013x64Link}", ($usmtTempPath + $msvc2013x64File))
        Invoke-Expression -Command:($msvc2013x64Install)
        $timeout = 0
        While (!(Test-ProgramInstalled("Microsoft Visual C\+\+ 2013 x64")))
        {
            Start-Sleep 5
            Write-ToLog -Message:("Waiting for Visual C++ 2013 x64 to finish installing")
            $timeout += 1
            if ($timeout -eq 10)
            {
                break
            }
        }
    }
    If (!(Test-ProgramInstalled("Microsoft Visual C\+\+ 2013 x86")))
    {
        Write-ToLog -Message:('Downloading & Installing JCAgent prereq Visual C++ 2013 x86')
        (New-Object System.Net.WebClient).DownloadFile("${msvc2013x86Link}", ($usmtTempPath + $msvc2013x86File))
        Invoke-Expression -Command:($msvc2013x86Install)
        $timeout = 0
        While (!(Test-ProgramInstalled("Microsoft Visual C\+\+ 2013 x86")))
        {
            Start-Sleep 5
            Write-ToLog -Message:("Waiting for Visual C++ 2013 x86 to finish installing")
            $timeout += 1
            if ($timeout -eq 10)
            {
                break
            }
        }
    }
    If (!(Test-Path -Path:(${AGENT_PATH} + '/' + ${AGENT_BINARY_NAME})))
    {
        Write-ToLog -Message:('Downloading JCAgent Installer')
        #Download Installer
        (New-Object System.Net.WebClient).DownloadFile("${AGENT_INSTALLER_URL}", ($AGENT_INSTALLER_PATH))
        Write-ToLog -Message:('JumpCloud Agent Download Complete')
        Write-ToLog -Message:('Running JCAgent Installer')
        #Run Installer
        $installJCParams = ("${AGENT_INSTALLER_PATH}", "-k ${JumpCloudConnectKey}", "/VERYSILENT", "/NORESTART", "/SUPRESSMSGBOXES", "/NOCLOSEAPPLICATIONS", "/NORESTARTAPPLICATIONS", "/LOG=$env:TEMP\jcUpdate.log")
        Invoke-Expression "$installJCParams"
        $timeout = 0
        while (!(Test-ProgramInstalled -programName:("JumpCloud")))
        {
            Start-Sleep 5
            $timeout += 1
            Write-ToLog -Message:('Waiting on JCAgent Installer...')
            if ($timeout -eq 20)
            {
                Write-ToLog -Message:('JCAgent did not install in the expected window')
                break
            }
        }
    }
    If ((Test-ProgramInstalled -programName:("Microsoft Visual C\+\+ 2013 x64")) -and (Test-ProgramInstalled -programName:("Microsoft Visual C\+\+ 2013 x86")) -and (Test-ProgramInstalled -programName:("JumpCloud")))
    {
        Return $true
    }
    Else
    {
        Return $false
    }
}
#TODO Add check if library installed on system, else don't import
Add-Type -MemberDefinition @"
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint NetApiBufferFree(IntPtr Buffer);
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int NetGetJoinInformation(
 string server,
 out IntPtr NameBuffer,
 out int BufferType);
"@ -Namespace Win32Api -Name NetApi32
function Get-NetBiosName
{
    $pNameBuffer = [IntPtr]::Zero
    $joinStatus = 0
    $apiResult = [Win32Api.NetApi32]::NetGetJoinInformation(
        $null, # lpServer
        [Ref] $pNameBuffer, # lpNameBuffer
        [Ref] $joinStatus    # BufferType
    )
    if ( $apiResult -eq 0 )
    {
        [Runtime.InteropServices.Marshal]::PtrToStringAuto($pNameBuffer)
        [Void] [Win32Api.NetApi32]::NetApiBufferFree($pNameBuffer)
    }
}
function Convert-Sid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $Sid
    )
    process
    {
        try
        {
            (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate( [System.Security.Principal.NTAccount]).Value
        }
        catch
        {
            return $Sid
        }
    }
}
function Convert-UserName
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $user
    )
    process
    {
        try
        {
            (New-Object System.Security.Principal.NTAccount($user)).Translate( [System.Security.Principal.SecurityIdentifier]).Value
        }
        catch
        {
            return $user
        }
    }
}
function Test-UsernameOrSID
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $usernameorsid
    )
    Begin
    {
        $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
        $localcomputersidprefix = ((Get-LocalUser | Select-Object -First 1).SID).AccountDomainSID.ToString()
        $convertedUser = Convert-UserName $usernameorsid
        $registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        $list = @()
        foreach ($profile in $registyProfiles)
        {
            $list += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
        }
        $users = @()
        foreach ($listItem in $list)
        {
            $isValidFormat = [regex]::IsMatch($($listItem.PSChildName), $sidPattern);
            # Get Valid SIDS
            if ($isValidFormat)
            {
                $users += [PSCustomObject]@{
                    Name = Convert-Sid $listItem.PSChildName
                    SID  = $listItem.PSChildName
                }
            }
        }
    }
    process
    {
        #check if sid, if valid sid and return sid
        if ([regex]::IsMatch($usernameorsid, $sidPattern))
        {
            if (($usernameorsid -in $users.SID) -And !($users.SID.Contains($localcomputersidprefix)))
            {
                # return, it's a valid SID
                Write-ToLog "valid sid returning sid"
                return $usernameorsid
            }
        }
        elseif ([regex]::IsMatch($convertedUser, $sidPattern))
        {
            if (($convertedUser -in $users.SID) -And !($users.SID.Contains($localcomputersidprefix)))
            {
                # return, it's a valid SID
                Write-ToLog "valid user returning sid"
                return $convertedUser
            }
        }
        else
        {
            Write-ToLog 'SID or Username is invalid'
            throw 'SID or Username is invalid'
        }
    }
}
#endregion Functions
#region Agent Install Helper Functions
Function Restart-ComputerWithDelay
{
    Param(
        [int]$TimeOut = 10
    )
    $continue = $true
    while ($continue)
    {
        If ([console]::KeyAvailable)
        {
            Write-Output "Restart Canceled by key press"
            Exit;
        }
        Else
        {
            Write-Output "Press any key to cancel... restarting in $TimeOut" -NoNewLine
            Start-Sleep -Seconds 1
            $TimeOut = $TimeOut - 1
            Clear-Host
            If ($TimeOut -eq 0)
            {
                $continue = $false
                $Restart = $true
            }
        }
    }
    If ($Restart -eq $True)
    {
        Write-Output "Restarting Computer..."
        Restart-Computer -ComputerName $env:COMPUTERNAME -Force
    }
}
#endregion Agent Install Helper Functions
Function Start-Migration
{
    [CmdletBinding(HelpURI = "https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/Start-Migration")]
    Param (
        [Parameter(ParameterSetName = 'cmd', Mandatory = $true)][string]$JumpCloudUserName,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $true)][string]$SelectedUserName,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TempPassword,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$LeaveDomain = $false,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$ForceReboot = $false,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$UpdateHomePath = $false,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$InstallJCAgent = $false,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$AutobindJCUser = $false,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][ValidateLength(40, 40)][string]$JumpCloudConnectKey,
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][ValidateLength(40, 40)][string]$JumpCloudAPIKey,
        [Parameter(ParameterSetName = "form")][Object]$inputObject)
    Begin
    {
        If (($InstallJCAgent -eq $true) -and ([string]::IsNullOrEmpty($JumpCloudConnectKey))) { Throw [System.Management.Automation.ValidationMetadataException] "You must supply a value for JumpCloudConnectKey when installing the JC Agent" }else {}
        If (($AutobindJCUser -eq $true) -and ([string]::IsNullOrEmpty($JumpCloudAPIKey))) { Throw [System.Management.Automation.ValidationMetadataException] "You must supply a value for JumpCloudAPIKey when autobinding a JC User" }else {}
        # Start script
        $admuVersion = '2.0.0'
        Write-ToLog -Message:('####################################' + (get-date -format "dd-MMM-yyyy HH:mm") + '####################################')
        Write-ToLog -Message:('Running ADMU: ' + 'v' + $admuVersion)
        Write-ToLog -Message:('Script starting; Log file location: ' + $jcAdmuLogFile)
        Write-ToLog -Message:('Gathering system & profile information')
        # Conditional ParameterSet logic
        If ($PSCmdlet.ParameterSetName -eq "form")
        {
            $SelectedUserName = $inputObject.SelectedUserName
            $JumpCloudUserName = $inputObject.JumpCloudUserName
            $TempPassword = $inputObject.TempPassword
            if (($inputObject.JumpCloudConnectKey).Length -eq 40)
            {
                $JumpCloudConnectKey = $inputObject.JumpCloudConnectKey
            }
            if (($inputObject.JumpCloudAPIKey).Length -eq 40)
            {
                $JumpCloudAPIKey = $inputObject.JumpCloudAPIKey
            }
            $InstallJCAgent = $inputObject.InstallJCAgent
            $AutobindJCUser = $inputObject.AutobindJCUser
            $LeaveDomain = $InputObject.LeaveDomain
            $ForceReboot = $InputObject.ForceReboot
            $UpdateHomePath = $inputObject.UpdateHomePath
            $displayGuiPrompt = $true
        }
        # Define misc static variables
        $netBiosName = Get-NetBiosName
        $WmiComputerSystem = Get-WmiObject -Class:('Win32_ComputerSystem')
        $localComputerName = $WmiComputerSystem.Name
        $windowsDrive = Get-WindowsDrive
        $jcAdmuTempPath = "$windowsDrive\Windows\Temp\JCADMU\"
        $jcAdmuLogFile = "$windowsDrive\Windows\Temp\jcAdmu.log"
        $msvc2013x64File = 'vc_redist.x64.exe'
        $msvc2013x86File = 'vc_redist.x86.exe'
        $msvc2013x86Link = 'http://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe'
        $msvc2013x64Link = 'http://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe'
        $msvc2013x86Install = "$jcAdmuTempPath$msvc2013x86File /install /quiet /norestart"
        $msvc2013x64Install = "$jcAdmuTempPath$msvc2013x64File /install /quiet /norestart"
        $netBiosName = Get-NetBiosName
        # JumpCloud Agent Installation Variables
        $AGENT_PATH = "${env:ProgramFiles}\JumpCloud"
        $AGENT_BINARY_NAME = "JumpCloud-agent.exe"
        $AGENT_INSTALLER_URL = "https://s3.amazonaws.com/jumpcloud-windows-agent/production/JumpCloudInstaller.exe"
        $AGENT_INSTALLER_PATH = "$windowsDrive\windows\Temp\JCADMU\JumpCloudInstaller.exe"
        # Track migration steps
        $admuTracker = [Ordered]@{
            backupOldUserReg    = @{'pass' = $false; 'fail' = $false }
            newUserCreate       = @{'pass' = $false; 'fail' = $false }
            newUserInit         = @{'pass' = $false; 'fail' = $false }
            backupNewUserReg    = @{'pass' = $false; 'fail' = $false }
            testRegLoadUnload   = @{'pass' = $false; 'fail' = $false }
            copyRegistry        = @{'pass' = $false; 'fail' = $false }
            copyRegistryFiles   = @{'pass' = $false; 'fail' = $false }
            renameOriginalFiles = @{'pass' = $false; 'fail' = $false }
            renameBackupFiles   = @{'pass' = $false; 'fail' = $false }
            renameHomeDirectory = @{'pass' = $false; 'fail' = $false }
            ntfsAccess          = @{'pass' = $false; 'fail' = $false }
            ntfsPermissions     = @{'pass' = $false; 'fail' = $false }
            activeSetupHKLM     = @{'pass' = $false; 'fail' = $false }
            activeSetupHKU      = @{'pass' = $false; 'fail' = $false }
            uwpAppXPacakges     = @{'pass' = $false; 'fail' = $false }
            uwpDownloadExe      = @{'pass' = $false; 'fail' = $false }
            leaveDomain         = @{'pass' = $false; 'fail' = $false }
            autoBind            = @{'pass' = $false; 'fail' = $false }
        }
        Write-ToLog -Message("The Selected Migration user is: $SelectedUserName")
        $SelectedUserSid = Test-UsernameOrSID $SelectedUserName
        Write-ToLog -Message:('Creating JCADMU Temporary Path in ' + $jcAdmuTempPath)
        if (!(Test-path $jcAdmuTempPath))
        {
            new-item -ItemType Directory -Force -Path $jcAdmuTempPath 2>&1 | Write-Verbose
        }
        Write-ToLog -Message:($localComputerName + ' is currently Domain joined to ' + $WmiComputerSystem.Domain + ' NetBiosName is ' + $netBiosName)
    }
    Process
    {
        # Start Of Console Output
        Write-ToLog -Message:('Windows Profile "' + $SelectedUserName + '" is going to be converted to "' + $localComputerName + '\' + $JumpCloudUserName + '"')
        #region SilentAgentInstall
        if ($InstallJCAgent -eq $true -and (!(Test-ProgramInstalled("Jumpcloud"))))
        {
            #check if jc is not installed and clear folder
            if (Test-Path "$windowsDrive\Program Files\Jumpcloud\")
            {
                Remove-ItemIfExist -Path "$windowsDrive\Program Files\Jumpcloud\" -Recurse
            }
            # Agent Installer
            Install-JumpCloudAgent -msvc2013x64link:($msvc2013x64Link) -msvc2013path:($jcAdmuTempPath) -msvc2013x64file:($msvc2013x64File) -msvc2013x64install:($msvc2013x64Install) -msvc2013x86link:($msvc2013x86Link) -msvc2013x86file:($msvc2013x86File) -msvc2013x86install:($msvc2013x86Install) -AGENT_INSTALLER_URL:($AGENT_INSTALLER_URL) -AGENT_INSTALLER_PATH:($AGENT_INSTALLER_PATH) -JumpCloudConnectKey:($JumpCloudConnectKey) -AGENT_PATH:($AGENT_PATH) -AGENT_BINARY_NAME:($AGENT_BINARY_NAME)
            start-sleep -seconds 20
            if ((Get-Content -Path ($env:LOCALAPPDATA + '\Temp\jcagent.log') -Tail 1) -match 'Agent exiting with exitCode=1')
            {
                Write-ToLog -Message:('JumpCloud agent installation failed - Check connect key is correct and network connection is active. Connectkey:' + $JumpCloudConnectKey) -Level:('Error')
                taskkill /IM "JumpCloudInstaller.exe" /F
                taskkill /IM "JumpCloudInstaller.tmp" /F
                Read-Host -Prompt "Press Enter to exit"
                exit
            }
            elseif (((Get-Content -Path ($env:LOCALAPPDATA + '\Temp\jcagent.log') -Tail 1) -match 'Agent exiting with exitCode=0'))
            {
                Write-ToLog -Message:('JC Agent installed - Must be off domain to start jc agent service')
            }
        }
        elseif ($InstallJCAgent -eq $true -and (Test-ProgramInstalled("Jumpcloud")))
        {
            Write-ToLog -Message:('JumpCloud agent is already installed on the system.')
        }
        ### Begin Backup Registry for Selected User ###
        Write-ToLog -Message:('Creating Backup of User Registry Hive')
        # Get Profile Image Path from Registry
        $oldUserProfileImagePath = Get-ItemPropertyValue -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath'
        # Backup Registry NTUSER.DAT and UsrClass.dat files
        try
        {
            Backup-RegistryHive -profileImagePath $oldUserProfileImagePath
        }
        catch
        {
            Write-ToLog -Message("Could Not Backup Registry Hives: Exiting...")
            Write-ToLog -Message($_.Exception.Message)
            $admuTracker.backupOldUserReg.fail = $true
            return
        }
        $admuTracker.backupOldUserReg.pass = $true
        ### End Backup Registry for Selected User ###
        ### Begin Create New User Region ###
        Write-ToLog -Message:('Creating New Local User ' + $localComputerName + '\' + $JumpCloudUserName)
        # Create New User
        $newUserPassword = ConvertTo-SecureString -String $TempPassword -AsPlainText -Force
        New-localUser -Name $JumpCloudUserName -password $newUserPassword -Description "Created By JumpCloud ADMU" -ErrorVariable userExitCode
        if ($userExitCode)
        {
            Write-ToLog -Message:("$userExitCode")
            Write-ToLog -Message:("The user: $JumpCloudUserName could not be created, exiting")
            $admuTracker.newUserCreate.fail = $true
            return
        }
        $admuTracker.newUserCreate.pass = $true
        # Initialize the Profile & Set SID
        $NewUserSID = New-LocalUserProfile -username:($JumpCloudUserName) -ErrorVariable profileInit
        if ($profileInit)
        {
            Write-ToLog -Message:("$profileInit")
            Write-ToLog -Message:("The user: $JumpCloudUserName could not be initalized, exiting")
            $admuTracker.newUserInit.fail = $true
            return
        }
        else
        {
            Write-ToLog -Message:('Getting new profile image path')
            # Get profile image path for new user
            $newUserProfileImagePath = Get-ProfileImagePath -UserSid $NewUserSID
            if ([System.String]::IsNullOrEmpty($newUserProfileImagePath))
            {
                Write-ToLog -Message("Could not get the profile path for $jumpcloudusername exiting...") -level Warn
                $admuTracker.newUserInit.fail = $true
                return
            }
            else
            {
                Write-ToLog -Message:('New User Profile Path: ' + $newUserProfileImagePath + ' New User SID: ' + $NewUserSID)
                Write-ToLog -Message:('Old User Profile Path: ' + $oldUserProfileImagePath + ' Old User SID: ' + $SelectedUserSID)
            }
        }
        $admuTracker.newUserInit.pass = $true
        ### End Create New User Region ###
        ### Begin backup user registry for new user
        try
        {
            Backup-RegistryHive -profileImagePath $newUserProfileImagePath
        }
        catch
        {
            Write-ToLog -Message("Could Not Backup Registry Hives in $($newUserProfileImagePath): Exiting...") -level Warn
            Write-ToLog -Message($_.Exception.Message)
            $admuTracker.backupNewUserReg.fail = $true
            return
        }
        $admuTracker.backupNewUserReg.pass = $true
        ### End backup user registry for new user
        ### Begin Test Registry Steps
        # Test Registry Access before edits
        Write-ToLog -Message:('Verifying Registry Hives can be loaded and unloaded')
        try
        {
            Test-UserRegistryLoadState -ProfilePath $newUserProfileImagePath -UserSid $newUserSid
            Test-UserRegistryLoadState -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSID
        }
        catch
        {
            Write-ToLog -Message:('could not load and unload registry of migration user, exiting') -level Warn
            $admuTracker.testRegLoadUnload.fail = $true
            return
        }
        $admuTracker.testRegLoadUnload.pass = $true
        ### End Test Registry
        Write-ToLog -Message:('Begin new local user registry copy')
        # Give us admin rights to modify
        Write-ToLog -Message:("Take Ownership of $($newUserProfileImagePath)")
        $path = takeown /F "$($newUserProfileImagePath)" /r /d Y
        Write-ToLog -Message:("Get ACLs for $($newUserProfileImagePath)")
        $acl = Get-Acl ($newUserProfileImagePath)
        Write-ToLog -Message:("Current ACLs: $($acl.access)")
        Write-ToLog -Message:("Setting Administrator Group Access Rule on: $($newUserProfileImagePath)")
        $AdministratorsGroupSIDName = ([wmi]"Win32_SID.SID='S-1-5-32-544'").AccountName
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdministratorsGroupSIDName, "FullControl", "Allow")
        Write-ToLog -Message:("Set ACL Access Protection Rules")
        $acl.SetAccessRuleProtection($false, $true)
        Write-ToLog -Message:("Set ACL Access Rules")
        $acl.SetAccessRule($AccessRule)
        Write-ToLog -Message:("Applying ACL...")
        $acl | Set-Acl $newUserProfileImagePath
        # Load New User Profile Registry Keys
        Set-UserRegistryLoadState -op "Load" -ProfilePath $newUserProfileImagePath -UserSid $NewUserSID
        # Load Selected User Profile Keys
        Set-UserRegistryLoadState -op "Load" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSID
        # Copy from "SelectedUser" to "NewUser"
        reg copy HKU\$($SelectedUserSID)_admu HKU\$($NewUserSID)_admu /s /f
        if ($?)
        {
            Write-ToLog -Message:('Copy Profile: ' + "$newUserProfileImagePath/NTUSER.DAT.BAK" + ' To: ' + "$oldUserProfileImagePath/NTUSER.DAT.BAK")
        }
        else
        {
            Write-ToLog -Message:('Could not copy Profile: ' + "$newUserProfileImagePath/NTUSER.DAT.BAK" + ' To: ' + "$oldUserProfileImagePath/NTUSER.DAT.BAK")
            $admuTracker.copyRegistry.fail = $true
            return
        }
        reg copy HKU\$($SelectedUserSID)_Classes_admu HKU\$($NewUserSID)_Classes_admu /s /f
        if ($?)
        {
            Write-ToLog -Message:('Copy Profile: ' + "$newUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$oldUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat")
        }
        else
        {
            Write-ToLog -Message:('Could not copy Profile: ' + "$newUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat" + ' To: ' + "$oldUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat")
            $admuTracker.copyRegistry.fail = $true
            return
        }
        $admuTracker.copyRegistry.pass = $true
        # Copy the profile containing the correct access and data to the destination profile
        Write-ToLog -Message:('Copying merged profiles to destination profile path')
        # Set Registry Check Key for New User
        # Check that the installed components key does not exist
        if ((Get-psdrive | select-object name) -notmatch "HKEY_USERS")
        {
            Write-ToLog "Mounting HKEY_USERS to check USER UWP keys"
            New-PSDrive -Name:("HKEY_USERS") -PSProvider:("Registry") -Root:("HKEY_USERS")
        }
        $ADMU_PackageKey = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
        if (Get-Item $ADMU_PackageKey -ErrorAction SilentlyContinue)
        {
            # If the account to be converted already has this key, reset the version
            $rootlessKey = $ADMU_PackageKey.Replace('HKEY_USERS:\', '')
            Set-ValueToKey -registryRoot Users -KeyPath $rootlessKey -name Version -value "0,0,00,0" -regValueKind String
        }
        # $admuTracker.activeSetupHKU = $true
        # Set the trigger to reset Appx Packages on first login
        $ADMUKEY = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\JCADMU"
        if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
        {
            # If the registry Key exists (it wont unless it's been previously migrated)
            Write-ToLog "The Key Already Exists"
            # collect unused references in memory and clear
            [gc]::collect()
            # Attempt to unload
            try {
                REG UNLOAD "HKU\$($newusersid)_admu" 2>&1 | out-null
            }
            catch{
                Write-ToLog "This account has been previously migrated"
            }
            # if ($UnloadReg){
            # }
        }
        else
        {
            # Create the new key & remind add tracking from previous domain account for reversion if necessary
            New-RegKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU"
            Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousSID" -value "$SelectedUserSID" -regValueKind String
            Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousProfilePath" -value "$oldUserProfileImagePath" -regValueKind String
        }
        ### End reg key check for new user
        # Unload "Selected" and "NewUser"
        Set-UserRegistryLoadState -op "Unload" -ProfilePath $newUserProfileImagePath -UserSid $NewUserSID
        Set-UserRegistryLoadState -op "Unload" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSID
        # Copy both registry hives over and replace the existing backup files in the destination directory.
        try
        {
            Copy-Item -Path "$newUserProfileImagePath/NTUSER.DAT.BAK" -Destination "$oldUserProfileImagePath/NTUSER.DAT.BAK" -Force -ErrorAction Stop
            Copy-Item -Path "$newUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Destination "$oldUserProfileImagePath/AppData/Local/Microsoft/Windows/UsrClass.dat.bak" -Force -ErrorAction Stop
        }
        catch
        {
            Write-ToLog -Message("Could not copy backup registry hives to the destination location in $($oldUserProfileImagePath): Exiting...")
            Write-ToLog -Message($_.Exception.Message)
            $admuTracker.copyRegistryFiles.fail = $true
            return
        }
        $admuTracker.copyRegistryFiles.pass = $true
        # Rename original ntuser & usrclass .dat files to ntuser_original.dat & usrclass_original.dat for backup and reversal if needed
        $renameDate = Get-Date -UFormat "%Y-%m-%d-%H%M%S"
        Write-ToLog -Message:("Copy orig. ntuser.dat to ntuser_original_$($renameDate).dat (backup reg step)")
        try
        {
            Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT" -NewName "$oldUserProfileImagePath\NTUSER_original_$renameDate.DAT" -Force -ErrorAction Stop
            Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original_$renameDate.dat" -Force -ErrorAction Stop
        }
        catch
        {
            Write-ToLog -Message("Could not rename original registry files for backup purposes: Exiting...")
            Write-ToLog -Message($_.Exception.Message)
            $admuTracker.renameOriginalFiles.fail = $true
            return
        }
        $admuTracker.renameOriginalFiles.pass = $true
        # finally set .dat.back registry files to the .dat in the profileimagepath
        Write-ToLog -Message:('rename ntuser.dat.bak to ntuser.dat (replace step)')
        try
        {
            Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT.BAK" -NewName "$oldUserProfileImagePath\NTUSER.DAT" -Force -ErrorAction Stop
            Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
        }
        catch
        {
            Write-ToLog -Message("Could not rename backup registry files to a system recognizable name: Exiting...")
            Write-ToLog -Message($_.Exception.Message)
            $admuTracker.renameBackupFiles.fail = $true
            return
        }
        $admuTracker.renameBackupFiles.pass = $true
        if ($UpdateHomePath)
        {
            Write-ToLog -Message:("Parameter to Update Home Path was set.")
            Write-ToLog -Message:("Attempting to rename $oldUserProfileImagePath to: $($windowsDrive)\Users\$JumpCloudUserName.")
            # Test Condition for same names
            # Check if the new user is named username.HOSTNAME or username.000, .001 etc.
            $userCompare = $oldUserProfileImagePath.Replace("$($windowsDrive)\Users\", "")
            if ($userCompare -eq $JumpCloudUserName)
            {
                Write-ToLog -Message:("Selected User Path and New User Path Match")
                # Remove the New User Profile Path, we want to just use the old Path
                try
                {
                    Write-ToLog -Message:("Attempting to remove newly created $newUserProfileImagePath")
                    start-sleep 1
                    icacls $newUserProfileImagePath /reset /t /c /l *> $null
                    start-sleep 1
                    # Reset permissions on newUserProfileImagePath
                    # -ErrorAction Stop; Remove-Item doesn't throw terminating errors
                    Remove-Item -Path ($newUserProfileImagePath) -Force -Recurse -ErrorAction Stop
                }
                catch
                {
                    Write-ToLog -Message:("Remove $newUserProfileImagePath failed, renaming to ADMU_unusedProfile_$JumpCloudUserName")
                    Rename-Item -Path $newUserProfileImagePath -NewName "ADMU_unusedProfile_$JumpCloudUserName" -ErrorAction Stop
                }
                # Set the New User Profile Image Path to Old User Profile Path (they are the same)
                $newUserProfileImagePath = $oldUserProfileImagePath
            }
            else
            {
                Write-ToLog -Message:("Selected User Path and New User Path Differ")
                try
                {
                    Write-ToLog -Message:("Attempting to remove newly created $newUserProfileImagePath")
                    # start-sleep 1
                    $systemAccount = whoami
                    Write-ToLog -Message:("ADMU running as $systemAccount")
                    if ($systemAccount -eq "NT AUTHORITY\SYSTEM")
                    {
                        icacls $newUserProfileImagePath /reset /t /c /l *> $null
                        takeown /r /d Y /f $newUserProfileImagePath
                    }
                    # Reset permissions on newUserProfileImagePath
                    # -ErrorAction Stop; Remove-Item doesn't throw terminating errors
                    Remove-Item -Path ($newUserProfileImagePath) -Force -Recurse -ErrorAction Stop
                }
                catch
                {
                    Write-ToLog -Message:("Remove $newUserProfileImagePath failed, renaming to ADMU_unusedProfile_$JumpCloudUserName")
                    Rename-Item -Path $newUserProfileImagePath -NewName "ADMU_unusedProfile_$JumpCloudUserName" -ErrorAction Stop
                }
                try
                {
                    Write-ToLog -Message:("Attempting to rename newly $oldUserProfileImagePath to $JumpcloudUserName")
                    # Rename the old user profile path to the new name
                    # -ErrorAction Stop; Rename-Item doesn't throw terminating errors
                    Rename-Item -Path $oldUserProfileImagePath -NewName $JumpCloudUserName -ErrorAction Stop
                }
                catch
                {
                    Write-ToLog -Message:("Unable to rename user profile path to new name - $JumpCloudUserName.")
                    $admuTracker.renameHomeDirectory.fail = $true
                }
            }
            $admuTracker.renameHomeDirectory.pass = $true
            # TODO: reverse track this if we fail later
        }
        else
        {
            Write-ToLog -Message:("Parameter to Update Home Path was not set.")
            Write-ToLog -Message:("The $JumpCloudUserName account will point to $oldUserProfileImagePath profile path")
            try
            {
                Write-ToLog -Message:("Attempting to remove newly created $newUserProfileImagePath")
                start-sleep 1
                icacls $newUserProfileImagePath /reset /t /c /l *> $null
                start-sleep 1
                # Reset permissions on newUserProfileImagePath
                # -ErrorAction Stop; Remove-Item doesn't throw terminating errors
                Remove-Item -Path ($newUserProfileImagePath) -Force -Recurse -ErrorAction Stop
            }
            catch
            {
                Write-ToLog -Message:("Remove $newUserProfileImagePath failed, renaming to ADMU_unusedProfile_$JumpCloudUserName")
                Rename-Item -Path $newUserProfileImagePath -NewName "ADMU_unusedProfile_$JumpCloudUserName" -ErrorAction Stop
            }
            # Set the New User Profile Image Path to Old User Profile Path (they are the same)
            $newUserProfileImagePath = $oldUserProfileImagePath
        }
        Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value ("$windowsDrive\Users\" + $SelectedUserName + '.' + $NetBiosName)
        Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $NewUserSID) -Name 'ProfileImagePath' -Value ($newUserProfileImagePath)
        # logging
        Write-ToLog -Message:('New User Profile Path: ' + $newUserProfileImagePath + ' New User SID: ' + $NewUserSID)
        Write-ToLog -Message:('Old User Profile Path: ' + $oldUserProfileImagePath + ' Old User SID: ' + $SelectedUserSID)
        Write-ToLog -Message:("NTFS ACLs on domain $windowsDrive\users\ dir")
        #ntfs acls on domain $windowsDrive\users\ dir
        $NewSPN_Name = $env:COMPUTERNAME + '\' + $JumpCloudUserName
        $Acl = Get-Acl $newUserProfileImagePath
        $Ar = New-Object system.security.accesscontrol.filesystemaccessrule($NewSPN_Name, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        $Acl | Set-Acl -Path $newUserProfileImagePath
        #TODO: reverse track this if we fail later
        ## End Regedit Block ##
        ### Active Setup Registry Entry ###
        Write-ToLog -Message:('Creating HKLM Registry Entries')
        # Root Key Path
        $ADMUKEY = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\ADMU-AppxPackage"
        # Remove Root from key to pass into functions
        $rootlessKey = $ADMUKEY.Replace('HKLM:\', '')
        # Property Values
        $propertyHash = @{
            IsInstalled = 1
            Locale      = "*"
            StubPath    = "uwp_jcadmu.exe"
            Version     = "1,0,00,0"
        }
        if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
        {
            Write-ToLog -message:("The ADMU Registry Key exits")
            $properties = Get-ItemProperty -Path "$ADMUKEY"
            foreach ($item in $propertyHash.Keys)
            {
                Write-ToLog -message:("Property: $($item) Value: $($properties.$item)")
            }
        }
        else
        {
            # write-host "The ADMU Registry Key does not exist"
            # Create the new key
            New-RegKey -keyPath $rootlessKey -registryRoot LocalMachine
            foreach ($item in $propertyHash.Keys)
            {
                # Eventually make this better
                if ($item -eq "IsInstalled")
                {
                    Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind Dword
                }
                else
                {
                    Set-ValueToKey -registryRoot LocalMachine -keyPath "$rootlessKey" -Name "$item" -value $propertyHash[$item] -regValueKind String
                }
            }
        }
        # $admuTracker.activeSetupHKLM = $true
        ### End Active Setup Registry Entry Region ###
        Write-ToLog -Message:('Updating UWP Apps for new user')
        $newUserProfileImagePath = Get-ItemPropertyValue -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $newusersid) -Name 'ProfileImagePath'
        $path = $newUserProfileImagePath + '\AppData\Local\JumpCloudADMU'
        If (!(test-path $path))
        {
            New-Item -ItemType Directory -Force -Path $path
        }
        $appxList = @()
        if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
        {
            # Find Appx User Apps by Username
            $appxList = Get-AppXpackage -user (Convert-Sid $SelectedUserSID) | Select-Object InstallLocation
        }
        else
        {
            $appxList = Get-AppXpackage -user $SelectedUserSID | Select-Object InstallLocation
        }
        if ($appxList.Count -eq 0)
        {
            # Get Common Apps in edge case:
            try
            {
                $appxList = Get-AppXpackage -AllUsers | Select-Object InstallLocation
            }
            catch
            {
                # if the primary trust relationship fails (needed for local conversion)
                $appxList = Get-AppXpackage | Select-Object InstallLocation
            }
        }
        $appxList | Export-CSV ($newUserProfileImagePath + '\AppData\Local\JumpCloudADMU\appx_manifest.csv') -Force
        # TODO: Test and return non terminating error here if failure
        # $admuTracker.uwpAppXPackages = $true
        # Download the appx register exe
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://github.com/TheJumpCloud/jumpcloud-ADMU/releases/latest/download/uwp_jcadmu.exe' -OutFile 'C:\windows\uwp_jcadmu.exe'
        Start-Sleep -Seconds 5
        try
        {
            Get-Item -Path "$windowsDrive\Windows\uwp_jcadmu.exe" -ErrorAction Stop
        }
        catch
        {
            Write-ToLog -Message("Could not find uwp_jcadmu.exe in $windowsDrive\Windows\ UWP Apps will not migrate")
            Write-ToLog -Message($_.Exception.Message)
            # TODO: Test and return non terminating error here if failure
            # TODO: Get the checksum
            # $admuTracker.uwpDownloadExe = $true
        }
        Write-ToLog -Message:('Profile Conversion Completed')
        #region Add To Local Users Group
        Add-LocalGroupMember -SID S-1-5-32-545 -Member $JumpCloudUserName -erroraction silentlycontinue
        #endregion Add To Local Users Group
        # TODO: test and return non-terminating error here
        #region AutobindUserToJCSystem
        if ($AutobindJCUser -eq $true)
        {
            $bindResult = BindUsernameToJCSystem -JcApiKey $JumpCloudAPIKey -JumpCloudUserName $JumpCloudUserName
            if ($bindResult)
            {
                Write-ToLog -Message:('jumpcloud autobind step succeeded for user ' + $JumpCloudUserName)
                $admuTracker.autoBind.pass = $true
            }
            else
            {
                Write-ToLog -Message:('jumpcloud autobind step failed, apikey or jumpcloud username is incorrect.') -Level:('Warn')
                # $admuTracker.autoBind.fail = $true
            }
        }
        #endregion AutobindUserToJCSystem
        #region Leave Domain or AzureAD
        if ($LeaveDomain -eq $true)
        {
            if ($netBiosName -match 'AzureAD')
            {
                if (([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).user.Value -match "S-1-5-18")) -eq $false)
                {
                    Write-ToLog -Message:('Unable to leave AzureAD, ADMU Script must be run as NTAuthority\SYSTEM.This will have to be completed manually. For more information on the requirements read https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki/Leaving-AzureAD-Domains') -Level:('Error')
                }
                else
                {
                    try
                    {
                        Write-ToLog -Message:('Leaving AzureAD Domain with dsregcmd.exe')
                        dsregcmd.exe /leave
                    }
                    catch
                    {
                        Write-ToLog -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Warn')
                        # $admuTracker.leaveDomain.fail = $true
                    }
                }
            }
            else
            {
                Try
                {
                    Write-ToLog -Message:('Leaving Domain')
                    $WmiComputerSystem.UnJoinDomainOrWorkGroup($null, $null, 0)
                }
                Catch
                {
                    Write-ToLog -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Warn')
                    # $admuTracker.leaveDomain.fail = $true
                }
            }
            $admuTracker.leaveDomain.pass = $true
        }
        # Cleanup Folders Again Before Reboot
        Write-ToLog -Message:('Removing Temp Files & Folders.')
        try
        {
            Remove-ItemIfExist -Path:($jcAdmuTempPath) -Recurse
        }
        catch
        {
            Write-ToLog -Message:('Failed to remove Temp Files & Folders.' + $jcAdmuTempPath)
        }
        if ($ForceReboot -eq $true)
        {
            Write-ToLog -Message:('Forcing reboot of the PC now')
            Restart-Computer -ComputerName $env:COMPUTERNAME -Force
        }
        #endregion SilentAgentInstall
    }
    End
    {
        $FixedErrors = @();
        # if we caught any errors and need to revert based on admuTracker status, do so here:
        if ($admuTracker | ForEach-Object { $_.values.fail -eq $true })
        {
            foreach ($trackedStep in $admuTracker.Keys)
            {
                if (($admuTracker[$trackedStep].fail -eq $true) -or ($admuTracker[$trackedStep].pass -eq $true))
                {
                    switch ($trackedStep)
                    {
                        # Case for reverting 'newUserInit' steps
                        'newUserInit'
                        {
                            Write-ToLog -Message:("Attempting to revert $($trackedStep) steps")
                            try
                            {
                                Remove-LocalUserProfile -username $JumpCloudUserName
                                Write-ToLog -Message:("User: $JumpCloudUserName was successfully removed from the local system")
                            }
                            catch
                            {
                                Write-ToLog -Message:("Could not remove the $JumpCloudUserName profile and user account") -Level Error
                            }
                            $FixedErrors += "$trackedStep"
                        }
                        # 'renameOriginalFiles'
                        # {
                        #     Write-ToLog -Message:("Attempting to revert $($trackedStep) steps")
                        #     ### Should we be using Rename-Item here or Move-Item to force overwrite?
                        #     if (Test-Path "$oldUserProfileImagePath\NTUSER_original.DAT" -PathType Leaf)
                        #     {
                        #         try
                        #         {
                        #             Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT" -NewName "$oldUserProfileImagePath\NTUSER_failedCopy.DAT" -Force -ErrorAction Stop
                        #             Rename-Item -Path "$oldUserProfileImagePath\NTUSER_original.DAT" -NewName "$oldUserProfileImagePath\NTUSER.DAT" -Force -ErrorAction Stop
                        #             Write-ToLog -Message:("User at profile path: $oldUserProfileImagePath should be able to login")
                        #         }
                        #         catch
                        #         {
                        #             Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\NTUSER_original.DAT") -Level Error
                        #         }
                        #     }
                        #     if (Test-Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -PathType Leaf)
                        #     {
                        #         try
                        #         {
                        #             Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_failedCopy.dat" -Force -ErrorAction Stop
                        #             Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
                        #         }
                        #         catch
                        #         {
                        #             Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat") -Level Error
                        #         }
                        #         $FixedErrors += "$trackedStep"
                        #     }
                        # }
                        # 'renameBackupFiles'
                        # {
                        #     Write-ToLog -Message:("Attempting to revert $($trackedStep) steps")
                        #     if (Test-Path "$oldUserProfileImagePath\NTUSER.DAT.BAK" -PathType Leaf)
                        #     {
                        #         try
                        #         {
                        #             Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT.BAK" -NewName "$oldUserProfileImagePath\NTUSER.DAT" -Force -ErrorAction Stop
                        #         }
                        #         catch
                        #         {
                        #             Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\NTUSER.DAT.BAK") -Level Error
                        #         }
                        #     }
                        #     if (Test-Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -PathType Leaf)
                        #     {
                        #         try
                        #         {
                        #             Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
                        #         }
                        #         catch
                        #         {
                        #             Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak") -Level Error
                        #         }
                        #     }
                        #     $FixedErrors += "$trackedStep"
                        # }
                        # 'renameHomeDirectory'
                        # {
                        #     try
                        #     {
                        #         Write-ToLog -Message:("Attempting to revert RenameHomeDirectory steps")
                        #         if (($userCompare -ne $selectedUserName) -and (test-path -Path $newUserProfileImagePath))
                        #         {
                        #             # Error Action stop to treat as terminating error
                        #             Rename-Item -Path ($newUserProfileImagePath) -NewName ($selectedUserName) -ErrorAction Stop
                        #         }
                        #         Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value "$($oldUserProfileImagePath)"
                        #     }
                        #     catch
                        #     {
                        #         Write-ToLog -Message:("Unable to restore old user profile path and profile image path.") -Level Error
                        #     }
                        #     $FixedErrors += "$trackedStep"
                        # }
                        Default
                        {
                            # Write-ToLog -Message:("default error") -Level Error
                        }
                    }
                }
            }
        }
        if ([System.String]::IsNullOrEmpty($($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true })))
        {
            Write-ToLog -Message:('Script finished successfully; Log file location: ' + $jcAdmuLogFile)
            Write-ToLog -Message:('Tool options chosen were : ' + "`nInstall JC Agent = " + $InstallJCAgent + "`nLeave Domain = " + $LeaveDomain + "`nForce Reboot = " + $ForceReboot + "`nUpdate Home Path" + $UpdateHomePath + "Autobind JC User" + $AutobindJCUser)
            if ($displayGuiPrompt)
            {
                Show-Result -domainUser $SelectedUserName $ -localUser "$($localComputerName)\$($JumpCloudUserName)" -success $true -profilePath $newUserProfileImagePath -logPath $jcAdmuLogFile
            }
        }
        else
        {
            Write-ToLog -Message:("ADMU encoutered the following errors: $($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true })") -Level Warn
            Write-ToLog -Message:("The following migration steps were reverted to their original state: $FixedErrors") -Level Warn
            if ($displayGuiPrompt)
            {
                Show-Result -domainUser $SelectedUserName $ -localUser "$($localComputerName)\$($JumpCloudUserName)" -success $false -profilePath $newUserProfileImagePath -admuTrackerInput $admuTracker -FixedErrors $FixedErrors -logPath $jcAdmuLogFile
            }
            throw "JumpCloud ADMU was unable to migrate $selectedUserName"
        }
    }
}
# Load form
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Loading ADMU GUI..'
# Base64 Encoded Strings of our Images
$JCLogoBase64 = "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"
$ErrorBase64 = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAFiSURBVHgBpVPNSsNAEJ4ZzwWv/lKfoPUN2oOl3lYKelAoPpkIelBQ4smih8YnMI8QqlQbL0JbT2bH2di0MXFD2n6w7OzMzscwMx/CP3hpqhoBtcWsySlHTmYPEL1Q67vtB8dJ52Dy8dZUZQY8k1ODfPgEur7WcfwM0eueqiJRVzyrUAQMn6x1ffPR8aZEphLN9JwmKR0fQunkKLKHF1cwvLzOkBHqXVMZmbeGOSpJQnJMK4xJvUZLQdzQBWD6GQ2HSCvbpzAIZvbgw0pGsNImZKxAAYTjcU6UZV0Qqrbw9/usCs4lgjLlRcMgQTTKJQJD5EMB6NGXPShbTwz8ZIuHg0SzE43PQKSDE111YRkwqWiz+82Drk1f6/c30d3fb9lo/I3O7U7UbAQ+NesOc1ciEhHx/nJMsKxop+M3DiNAKDBFGZBr/sYkfypKotdQiggVMlRkIvHC+nJcDfp8q+O46Zwfa3qRu77hWMMAAAAASUVORK5CYII="
$ActiveBase64 = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAGKSURBVHgBlZRPTsJQEMbfTBvccgTcKYFQlxJM2hvUEygnID2CJ6jKAZQTgCcoorK1Cf5hZ4/A1oQ3Y98j1FKLbWfTvnn9fp3ON68gcqL15NtsGhfIbLOAxibLITOECPJh0fUmWQ2kF0eB3zBreCcAbPFPsBCR/JbO0vGiP6Bm4FtYM4I4UxflYgVC9rfVwW8lxmsFSAIjks5HzwtRrYyDSpWko46Avq6oPRu6bPK4jIoFR0x0HotVH61kQ0oHCcktC5FA+jOIqb+zpxwGwE6eKA+yPPUi1U9AY5wR2CiArXQOiEfv3cGhuuZBVD9jhxo7mniN2WqkoGt1XfQGl4L5qgiSwNrz2y/e3Uws3SaKIMwcIgl+zOTriEbQfPatMhAdqI8O3edsadjxfOgWQlRFxBM92a2Xm6DofO2FxGYoc3Sz1xjPBYuVqBrMK2WGutUg5QqxdCrBNpC+0iYgFcqlNcqT7DDugUzj6XY+U/8lyHuuPfNdMtEFFp3tmYL4BQQwhbUcvZ1506zmB49h1CYDMPPcAAAAAElFTkSuQmCC"
$BlueBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAElSURBVHgBbVE7TsNAEH2z+dQ+wnKCmIY6nICCIEIXdymIYk4AnCBBEETpVBQWSjgBpEM0+Ag+ghGiQIl3GH/BcUaa1erNe292ZglFuAsLGzMGmwGItCCRZACGh1lvXtAoPYcLjYZ5AbEuDZg8wHRTMfEUtycXCax2kolCzI4dud3kYhcjf5J1GD1NwOyiHq+StqT1B/GhEnK3yjNzGLOPzdqpkhM+bJW7FBGBFMPEEZpNXW+qOgrZNoqwxEXj4SwUu0GNT/yZCIKttl5e7WyZJbUPEfB1BWx9PaebA63wfwbmEPF61cC7H+KgtyeEbBbT/oHisdz61ecYB/f9NyqBc/9K0EvUQ54VO7g7Xaa6Smn4qNFsHclH2cmAst4A7e8lpk45yy8GxWbP/ZW8WwAAAABJRU5ErkJggg=="
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
function DecodeBase64Image
{
    param (
        [Parameter(Mandatory = $true)]
        [String]$ImageBase64
    )
    # Parameter help description
    $ObjBitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage #Provides a specialized BitmapSource that is optimized for loading images using Extensible Application Markup Language (XAML).
    $ObjBitmapImage.BeginInit() #Signals the start of the BitmapImage initialization.
    $ObjBitmapImage.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($ImageBase64) #Creates a stream whose backing store is memory.
    $ObjBitmapImage.EndInit() #Signals the end of the BitmapImage initialization.
    $ObjBitmapImage.Freeze() #Makes the current object unmodifiable and sets its IsFrozen property to true.
    $ObjBitmapImage
}
# Set source here. Take note in the XAML as to where the variable name was taken.
#==============================================================================================
# XAML Code - Imported from Visual Studio WPF Application
#==============================================================================================
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[xml]$XAML = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="JumpCloud ADMU 2.0.0"
        WindowStyle="SingleBorderWindow"
        ResizeMode="NoResize"
        Background="White" ScrollViewer.VerticalScrollBarVisibility="Visible" ScrollViewer.HorizontalScrollBarVisibility="Visible" Width="1000" Height="490">
    <Grid Margin="0,0,0,0">
        <Grid.RowDefinitions>
            <RowDefinition/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="118*"/>
            <ColumnDefinition Width="57*"/>
            <ColumnDefinition Width="23*"/>
        </Grid.ColumnDefinitions>
        <ListView Name="lvProfileList" MinWidth="960" MinHeight="110" Width="960" MaxWidth="960" MaxHeight="110" Height="110" Margin="10,187,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" Grid.ColumnSpan="3">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="System Accounts" DisplayMemberBinding="{Binding UserName}" Width="300"/>
                    <GridViewColumn Header="Last Login" DisplayMemberBinding="{Binding LastLogin}" Width="135"/>
                    <GridViewColumn Header="Currently Active" DisplayMemberBinding="{Binding Loaded}" Width="145" />
                    <GridViewColumn Header="Local Admin" DisplayMemberBinding="{Binding IsLocalAdmin}" Width="115"/>
                    <GridViewColumn Header="Local Path" DisplayMemberBinding="{Binding LocalPath}" Width="225"/>
                </GridView>
            </ListView.View>
        </ListView>
        <GroupBox Header="System Migration Options" Width="480" FontWeight="Bold" HorizontalAlignment="Left" MinWidth="480" MinHeight="135" Margin="10,306,0,0" VerticalAlignment="Top" Height="138">
            <Grid HorizontalAlignment="Left" Height="121" VerticalAlignment="Top" Width="470">
                <TextBlock Name="lbl_connectkey" HorizontalAlignment="Left" Margin="3,13,0,0" Text="JumpCloud Connect Key :" VerticalAlignment="Top" TextDecorations="Underline" Foreground="#FF000CFF"/>
                <TextBox Name="tbJumpCloudConnectKey" HorizontalAlignment="Left" Height="23" Margin="178,10,0,0" Text="Enter JumpCloud Connect Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox Name="cb_installjcagent" Content="Install JCAgent" HorizontalAlignment="Left" Margin="123,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox Name="cb_leavedomain" Content="Leave Domain" HorizontalAlignment="Left" Margin="10,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox Name="cb_forcereboot" Content="Force Reboot" HorizontalAlignment="Left" Margin="10,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <TextBlock Name="lbl_apikey" HorizontalAlignment="Left" Margin="3,42,0,0" Text="JumpCloud API Key :" VerticalAlignment="Top" TextDecorations="Underline" Foreground="#FF000CFF"/>
                <TextBox Name="tbJumpCloudAPIKey" HorizontalAlignment="Left" Height="23" Margin="178,40,0,0" Text="Enter JumpCloud API Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox Name="cb_autobindjcuser" Content="Autobind JC User" HorizontalAlignment="Left" Margin="123,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <Image Name="img_ckey_info" HorizontalAlignment="Left" Height="14" Margin="157,13,0,0" VerticalAlignment="Top" Width="14" Visibility="Hidden" ToolTip="The Connect Key provides you with a means of associating this system with your JumpCloud organization. The Key is used to deploy the agent to this system." />
                <Image Name="img_ckey_valid" HorizontalAlignment="Left" Height="14" Margin="454,13,0,0" VerticalAlignment="Top" Width="14" Visibility="Hidden" ToolTip="Connect Key must be 40chars &amp; not contain spaces" />
                <Image Name="img_apikey_info" HorizontalAlignment="Left" Height="14" Margin="157,42,0,0" VerticalAlignment="Top" Width="14" Visibility="Hidden" ToolTip="Click the link for more info on how to obtain the api key. The API key must be from a user with at least 'Manager' or 'Administrator' privileges." RenderTransformOrigin="1.857,-1.066"/>
                <Image Name="img_apikey_valid" HorizontalAlignment="Left" Height="14" Margin="454,42,0,0" VerticalAlignment="Top" Width="14" Visibility="Hidden" ToolTip="Correct error" />
            </Grid>
        </GroupBox>
        <GroupBox Header="Account Migration Information" FontWeight="Bold" Height="107" Width="475" Margin="495,306,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" Grid.ColumnSpan="3">
            <Grid HorizontalAlignment="Left" Height="66" VerticalAlignment="Top" Width="461">
                <Label Content="Local Account Username :" HorizontalAlignment="Left" Margin="0,8,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <Label Content="Local Account Password :" HorizontalAlignment="Left" Margin="0,36,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <TextBox Name="tbJumpCloudUserName" HorizontalAlignment="Left" Height="23" Margin="192,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="235" Text="Username should match JumpCloud username" Background="#FFC6CBCF" FontWeight="Bold" />
                <TextBox Name="tbTempPassword" HorizontalAlignment="Left" Height="23" Margin="192,38,0,0" TextWrapping="Wrap" Text="Temp123!Temp123!" VerticalAlignment="Top" Width="235" FontWeight="Normal"/>
                <Image Name="img_localaccount_info" HorizontalAlignment="Left" Height="14" Margin="169,12,0,0" VerticalAlignment="Top" Width="14" Visibility="Visible" ToolTip="The value in this field should match a username in the jc console. A new local user account will be created with this username." />
                <Image Name="img_localaccount_valid" HorizontalAlignment="Left" Height="14" Margin="432,12,0,0" VerticalAlignment="Top" Width="14" ToolTip="Local account username can't be empty, contain spaces, already exist on the local system or match the local computer name." Visibility="Visible" />
                <Image Name="img_localaccount_password_info" HorizontalAlignment="Left" Height="14" Margin="169,42,0,0" VerticalAlignment="Top" Width="14" Visibility="Visible" ToolTip="This temporary password is used on account creation. The password will be ovewritten by the users jc password if autobound or manually bound in the console."/>
                <Image Name="img_localaccount_password_valid" HorizontalAlignment="Left" Height="14" Margin="432,40,0,0" VerticalAlignment="Top" Width="14" Visibility="Visible"/>
            </Grid>
        </GroupBox>
        <GroupBox Header="System Information" FontWeight="Bold" Width="303" Height="148" MaxHeight="160" Margin="10,34,0,0" HorizontalAlignment="Left" VerticalAlignment="Top">
            <Grid HorizontalAlignment="Left" Height="125" Margin="10,0,0,0" VerticalAlignment="Center" Width="245" MinWidth="245" MinHeight="125">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="125"/>
                    <ColumnDefinition Width="125"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                </Grid.RowDefinitions>
                <Label Content="Computer Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="0" />
                <Label Content="Domain Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="1" />
                <Label Content="NetBios Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="2" />
                <Label Content="AzureAD Joined:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="3" />
                <Label Content="Tenant Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="4"/>
                <Label Name="lbTenantName" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="4"/>
                <Label Name="lbAzureAD_Joined" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="3"/>
                <Label Name="lbComputerName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="0"/>
                <Label Name="lbDomainName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="1"/>
                <Label Name="lbNetBios" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="2"/>
            </Grid>
        </GroupBox>
        <Image Name="JCLogoImg" HorizontalAlignment="Left" Height="33" VerticalAlignment="Top" Margin="9,0,0,0" Width="500"/>
        <Button Name="bMigrateProfile" Content="Select Profile" HorizontalAlignment="Left" Margin="237,418,0,0" VerticalAlignment="Top" Width="146" Height="26" IsEnabled="False" Grid.Column="1" Grid.ColumnSpan="2"/>
        <GroupBox Header="Migration Steps" HorizontalAlignment="Left" Height="148" VerticalAlignment="Top" Width="655" FontWeight="Bold" Margin="315,34,0,0" Grid.ColumnSpan="3">
            <TextBlock HorizontalAlignment="Center" TextWrapping="Wrap" VerticalAlignment="Top" Height="118" Width="632" FontWeight="Normal"><Run Text="1. Select a domain or AzureAD account to be migrated to a local account from the list below."/><LineBreak/><Run Text="2. Enter a local account username and temporary password. The selected account will be migrated to this local account."/><LineBreak/><Run Text="3.(Optionally) Select Install JC Agent and provide a Connect Key to install the JC agent on this system."/><LineBreak/><Run Text="4.(Optionally) Select Autobind JC User and provide an API Key to bind the new local username to your JC organization."/><LineBreak/><Run Text="5.(Optionally) Select Force Reboot and/or Leave Domain as required."/><LineBreak/><Run Text="6. Click the Migrate Profile button."/><LineBreak/><Run Text="For further information check out the JC ADMU Wiki. - https://github.com/TheJumpCloud/jumpcloud-ADMU/wiki"/></TextBlock>
        </GroupBox>
    </Grid>
</Window>
'@
# Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
Try
{
    $Form = [Windows.Markup.XamlReader]::Load($reader)
}
Catch
{
    Write-Error "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered.";
    Exit;
}
#===========================================================================
# Store Form Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach-Object {
    New-Variable  -Name $_.Name -Value $Form.FindName($_.Name) -Force
}
$JCLogoImg.Source = DecodeBase64Image -ImageBase64 $JCLogoBase64
$img_ckey_info.Source = DecodeBase64Image -ImageBase64 $BlueBase64
$img_ckey_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
$img_apikey_info.Source = DecodeBase64Image -ImageBase64 $BlueBase64
$img_apikey_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
$img_localaccount_info.Source = DecodeBase64Image -ImageBase64 $BlueBase64
$img_localaccount_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
$img_localaccount_password_info.Source = DecodeBase64Image -ImageBase64 $BlueBase64
$img_localaccount_password_valid.Source = DecodeBase64Image -ImageBase64 $ActiveBase64
# Define misc static variables
$WmiComputerSystem = Get-WmiObject -Class:('Win32_ComputerSystem')
Write-progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..' -PercentComplete 25
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..'
if ($WmiComputerSystem.PartOfDomain)
{
    $WmiComputerDomain = Get-WmiObject -Class:('Win32_ntDomain')
    $securechannelstatus = Test-ComputerSecureChannel
    $nbtstat = nbtstat -n
    foreach ($line in $nbtStat)
    {
        if ($line -match '^\s*([^<\s]+)\s*<00>\s*GROUP')
        {
            $NetBiosName = $matches[1]
        }
    }
    if ([System.String]::IsNullOrEmpty($WmiComputerDomain[0].DnsForestName) -and $securechannelstatus -eq $false)
    {
        $DomainName = 'Fix Secure Channel'
    }
    else
    {
        $DomainName = [string]$WmiComputerDomain.DnsForestName
    }
    $NetBiosName = [string]$NetBiosName
}
elseif ($WmiComputerSystem.PartOfDomain -eq $false)
{
    $DomainName = 'N/A'
    $NetBiosName = 'N/A'
    $securechannelstatus = 'N/A'
}
if ((Get-CimInstance Win32_OperatingSystem).Version -match '10')
{
    $AzureADInfo = dsregcmd.exe /status
    foreach ($line in $AzureADInfo)
    {
        if ($line -match "AzureADJoined : ")
        {
            $AzureADStatus = ($line.trimstart('AzureADJoined : '))
        }
        if ($line -match "WorkplaceJoined : ")
        {
            $Workplace_join = ($line.trimstart('WorkplaceJoined : '))
        }
        if ($line -match "TenantName : ")
        {
            $TenantName = ($line.trimstart('WorkplaceTenantName : '))
        }
    }
}
else
{
    $AzureADStatus = 'N/A'
    $Workplace_join = 'N/A'
    $TenantName = 'N/A'
}
$FormResults = [PSCustomObject]@{ }
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..' -PercentComplete 50
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..'
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..' -PercentComplete 70
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..'
# Get Valid SIDs from the Registry and build user object
$registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileList = @()
foreach ($profile in $registyProfiles)
{
    $profileList += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
}
# List to store users
$users = @()
foreach ($listItem in $profileList)
{
    $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
    $isValidFormat = [regex]::IsMatch($($listItem.PSChildName), $sidPattern);
    # Get Valid SIDs
    if ($isValidFormat)
    {
        # Populate Users List
        $users += [PSCustomObject]@{
            Name              = Convert-Sid $listItem.PSChildName
            LocalPath         = $listItem.ProfileImagePath
            SID               = $listItem.PSChildName
            IsLocalAdmin      = $null
            LocalProfileSize  = $null
            Loaded            = $null
            RoamingConfigured = $null
            LastLogin         = $null
        }
    }
}
# Get Win32 Profiles to merge data with valid SIDs
$win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
$date_format = "yyyy-MM-dd HH:mm"
foreach ($user in $users)
{
    # Get Data from Win32Profile
    foreach ($win32user in $win32UserProfiles)
    {
        if ($($user.SID) -eq $($win32user.SID))
        {
            $user.RoamingConfigured = $win32user.RoamingConfigured
            $user.Loaded = $win32user.Loaded
            if ([string]::IsNullOrEmpty($($win32user.LastUseTime)))
            {
                $user.LastLogin = "N/A"
            }
            else
            {
                $user.LastLogin = [System.Management.ManagementDateTimeConverter]::ToDateTime($($win32user.LastUseTime)).ToUniversalTime().ToSTring($date_format)
            }
        }
    }
    # Get Admin Status
    try
    {
        $admin = Get-LocalGroupMember -Member "$($user.SID)" -Name "Administrators" -EA SilentlyContinue
    }
    catch
    {
        $user = Get-LocalGroupMember -Member "$($user.SID)" -Name "Users"
    }
    if ($admin)
    {
        $user.IsLocalAdmin = $true
    }
    else
    {
        $user.IsLocalAdmin = $false
    }
    # Get Profile Size
    # $largeprofile = Get-ChildItem $($user.LocalPath) -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Sum length | Select-Object -ExpandProperty Sum
    # $largeprofile = [math]::Round($largeprofile / 1MB, 0)
    # $user.LocalProfileSize = $largeprofile
}
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..' -PercentComplete 85
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..'
$Profiles = $users | Select-Object SID, RoamingConfigured, Loaded, IsLocalAdmin, LocalPath, LocalProfileSize, LastLogin, @{Name = "UserName"; EXPRESSION = { $_.Name } }
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Done!' -PercentComplete 100
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Done!'
#load UI Labels
#SystemInformation
$lbComputerName.Content = $WmiComputerSystem.Name
#DomainInformation
$lbDomainName.Content = $DomainName
$lbNetBios.Content = $NetBiosName
#AzureADInformation
$lbAzureAD_Joined.Content = $AzureADStatus
$lbTenantName.Content = $TenantName
Function Test-Button([object]$tbJumpCloudUserName, [object]$tbJumpCloudConnectKey, [object]$tbTempPassword, [object]$lvProfileList, [object]$tbJumpCloudAPIKey)
{
    If (![System.String]::IsNullOrEmpty($lvProfileList.SelectedItem.UserName))
    {
        If (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true))`
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !(($($lvProfileList.selectedItem.Username) -split '\\')[0] -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bMigrateProfile.Content = "Migrate Profile"
            $script:bMigrateProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true) -and ($cb_autobindjcuser.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bMigrateProfile.Content = "Migrate Profile"
            $script:bMigrateProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true) -and ($cb_installjcagent.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bMigrateProfile.Content = "Migrate Profile"
            $script:bMigrateProfile.IsEnabled = $true
            Return $true
        }
        Elseif (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ($cb_installjcagent.IsChecked -eq $false) -and ($cb_autobindjcuser.IsChecked -eq $false)`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bMigrateProfile.Content = "Migrate Profile"
            $script:bMigrateProfile.IsEnabled = $true
            Return $true
        }
        Elseif ($lvProfileList.selectedItem.Username -eq 'UNKNOWN ACCOUNT')
        {
            # Unmatched Profile, prevent migration
            $script:bMigrateProfile.Content = "Select Domain Profile"
            $script:bMigrateProfile.IsEnabled = $false
            Return $false
        }
        elseif (($($lvProfileList.selectedItem.Username) -split '\\')[0] -match $WmiComputerSystem.Name)
        {
            $script:bMigrateProfile.Content = "Select Domain Profile"
            $script:bMigrateProfile.IsEnabled = $false
            Return $false
        }
        Else
        {
            $script:bMigrateProfile.Content = "Migrate Profile"
            $script:bMigrateProfile.IsEnabled = $false
            Return $false
        }
    }
    Else
    {
        $script:bMigrateProfile.Content = "Select Profile"
        $script:bMigrateProfile.IsEnabled = $false
        Return $false
    }
}
## Form changes & interactions
# Install JCAgent checkbox
$script:InstallJCAgent = $false
$cb_installjcagent.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Checked( { $script:InstallJCAgent = $true })
$cb_installjcagent.Add_Checked( { $tbJumpCloudConnectKey.IsEnabled = $true })
$cb_installjcagent.Add_Checked( { $img_ckey_info.Visibility = 'Visible'})
$cb_installjcagent.Add_Checked( { $img_ckey_valid.Visibility = 'Visible'})
$cb_installjcagent.Add_Checked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text)) -eq $false)
    {
        #$tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
        $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudConnectKey.Background = "white"
        $tbJumpCloudConnectKey.Tooltip = $null
        $tbJumpCloudConnectKey.FontWeight = "Normal"
        $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
    }
})
$cb_installjcagent.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Unchecked( { $script:InstallJCAgent = $false })
$cb_installjcagent.Add_Unchecked( { $tbJumpCloudConnectKey.IsEnabled = $false })
$cb_installjcagent.Add_Unchecked( {$img_ckey_info.Visibility = 'Hidden'})
$cb_installjcagent.Add_Unchecked( {$img_ckey_valid.Visibility = 'Hidden'})
$cb_installjcagent.Add_Unchecked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -or ($cb_installjcagent.IsEnabled)) -eq $false)
    {
        #$tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
        $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudConnectKey.Background = "white"
        $tbJumpCloudConnectKey.Tooltip = $null
        $tbJumpCloudConnectKey.FontWeight = "Normal"
        $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
    }
})
# Autobind JC User checkbox
$script:AutobindJCUser = $false
$cb_autobindjcuser.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Checked( { $script:AutobindJCUser = $true })
$cb_autobindjcuser.Add_Checked( { $tbJumpCloudAPIKey.IsEnabled = $true })
$cb_autobindjcuser.Add_Checked( { $img_apikey_info.Visibility = 'Visible'})
$cb_autobindjcuser.Add_Checked( { $img_apikey_valid.Visibility = 'Visible'})
$cb_autobindjcuser.Add_Checked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text)) -eq $false)
    {
        #$tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudAPIKey.Background = "white"
        $tbJumpCloudAPIKey.Tooltip = $null
        $tbJumpCloudAPIKey.FontWeight = "Normal"
        $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
    }
})
$cb_autobindjcuser.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Unchecked( { $script:AutobindJCUser = $false })
$cb_autobindjcuser.Add_Unchecked( { $tbJumpCloudAPIKey.IsEnabled = $false })
$cb_autobindjcuser.Add_Unchecked( { $img_apikey_info.Visibility = 'Hidden'})
$cb_autobindjcuser.Add_Unchecked( { $img_apikey_valid.Visibility = 'Hidden'})
$cb_autobindjcuser.Add_Unchecked( {
    Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
    If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -or ($cb_autobindjcuser.IsEnabled)) -eq $false)
    {
        #$tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
        $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
    }
    Else
    {
        $tbJumpCloudAPIKey.Background = "white"
        $tbJumpCloudAPIKey.Tooltip = $null
        $tbJumpCloudAPIKey.FontWeight = "Normal"
        $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
    }
})
# Leave Domain checkbox
$script:LeaveDomain = $false
$cb_leavedomain.Add_Checked( { $script:LeaveDomain = $true })
$cb_leavedomain.Add_Unchecked( { $script:LeaveDomain = $false })
# Force Reboot checkbox
$script:ForceReboot = $false
$cb_forcereboot.Add_Checked( { $script:ForceReboot = $true })
$cb_forcereboot.Add_Unchecked( { $script:ForceReboot = $false })
$tbJumpCloudUserName.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((Test-IsNotEmpty $tbJumpCloudUserName.Text) -or (!(Test-HasNoSpace $tbJumpCloudUserName.Text)) -or (Test-Localusername $tbJumpCloudUserName.Text))
        {
            $tbJumpCloudUserName.Background = "#FFC6CBCF"
            $tbJumpCloudUserName.BorderBrush = "#FFF90000"
            $img_localaccount_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
            $img_localaccount_valid.ToolTip= "Local account username can't be empty, contain spaces, already exist on the local system or match the local computer name."
        }
        Else
        {
            $tbJumpCloudUserName.Background = "white"
            $tbJumpCloudUserName.FontWeight = "Normal"
            $tbJumpCloudUserName.BorderBrush = "#FFC6CBCF"
            $img_localaccount_valid.Source = DecodeBase64Image -ImageBase64 $ActiveBase64
            $img_localaccount_valid.ToolTip= $null
        }
    })
$tbJumpCloudConnectKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text)) -eq $false)
        {
            $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
            $tbJumpCloudConnectKey.BorderBrush = "#FFF90000"
            $img_ckey_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
            $img_ckey_valid.ToolTip= "Connect Key must be 40chars & not contain spaces."
        }
        Else
        {
            $tbJumpCloudConnectKey.Background = "white"
            $tbJumpCloudConnectKey.FontWeight = "Normal"
            $tbJumpCloudConnectKey.BorderBrush = "#FFC6CBCF"
            $img_ckey_valid.Source = DecodeBase64Image -ImageBase64 $ActiveBase64
            $img_ckey_valid.ToolTip= $null
        }
    })
$tbJumpCloudAPIKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text)) -eq $false)
        {
            $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
            $tbJumpCloudAPIKey.BorderBrush = "#FFF90000"
            $img_apikey_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
            $img_apikey_valid.ToolTip= "Jumpcloud API Key must be 40chars & not contain spaces."
        }
        Else
        {
            $tbJumpCloudAPIKey.Background = "white"
            $tbJumpCloudAPIKey.Tooltip = $null
            $tbJumpCloudAPIKey.FontWeight = "Normal"
            $tbJumpCloudAPIKey.BorderBrush = "#FFC6CBCF"
            $img_apikey_valid.Source = DecodeBase64Image -ImageBase64 $ActiveBase64
            $img_apikey_valid.ToolTip= $null
        }
    })
$tbTempPassword.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((!(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)) -eq $false)
        {
            $tbTempPassword.Background = "#FFC6CBCF"
            $tbTempPassword.BorderBrush = "#FFF90000"
            $img_localaccount_password_valid.Source = DecodeBase64Image -ImageBase64 $ErrorBase64
            $img_localaccount_password_valid.ToolTip= "Local Account Temp Password should not be empty or contain spaces, it should also meet local password policy req. on the system."
        }
        Else
        {
            $tbTempPassword.Background = "white"
            $tbTempPassword.Tooltip = $null
            $tbTempPassword.FontWeight = "Normal"
            $tbTempPassword.BorderBrush = "#FFC6CBCF"
            $img_localaccount_password_valid.Source = DecodeBase64Image -ImageBase64 $ActiveBase64
            $img_localaccount_password_valid.ToolTip= $null
        }
    })
# Change button when profile selected
$lvProfileList.Add_SelectionChanged( {
        $script:SelectedUserName = ($lvProfileList.SelectedItem.username)
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        try
        {
            $SelectedUserSID = ((New-Object System.Security.Principal.NTAccount($script:SelectedUserName)).Translate( [System.Security.Principal.SecurityIdentifier]).Value)
        }
        catch
        {
            $SelectedUserSID = $script:SelectedUserName
        }
        $hku = ('HKU:\' + $SelectedUserSID)
        if (Test-Path -Path $hku)
        {
            $script:bMigrateProfile.Content = "User Registry Loaded"
            $script:bMigrateProfile.IsEnabled = $false
            $script:tbJumpCloudUserName.IsEnabled = $false
            $script:tbTempPassword.IsEnabled = $false
        }
        else
        {
            $script:tbJumpCloudUserName.IsEnabled = $true
            $script:tbTempPassword.IsEnabled = $true
        }
    })
$bMigrateProfile.Add_Click( {
        if ($tbJumpCloudAPIKey.Text -And $tbJumpCloudUserName.Text -And $AutobindJCUser) {
            $testResult, $userID = Test-JumpCloudUsername -JumpCloudApiKey $tbJumpCloudAPIKey.Text -Username $tbJumpCloudUserName.Text -Prompt $true
            if ($testResult) {
                Write-ToLog "Matched $($tbJumpCloudUserName.Text) with user in the JumpCloud Console"
            }
            else{
                Write-ToLog "$($tbJumpCloudUserName.Text) not found in the JumpCloud console"
                return
            }
        }
        # Build FormResults object
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('InstallJCAgent') -Value:($InstallJCAgent)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('AutobindJCUser') -Value:($AutobindJCUser)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('LeaveDomain') -Value:($LeaveDomain)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('ForceReboot') -Value:($ForceReboot)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('SelectedUserName') -Value:($SelectedUserName)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudUserName') -Value:($tbJumpCloudUserName.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('TempPassword') -Value:($tbTempPassword.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($tbJumpCloudConnectKey.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudAPIKey') -Value:($tbJumpCloudAPIKey.Text)
        # Close form
        $Form.Close()
    })
$tbJumpCloudUserName.add_GotFocus( {
    $tbJumpCloudUserName.Text = ""
})
$tbJumpCloudConnectKey.add_GotFocus( {
        $tbJumpCloudConnectKey.Text = ""
    })
$tbJumpCloudAPIKey.add_GotFocus( {
        $tbJumpCloudAPIKey.Text = ""
    })
# lbl_connectkey link - Mouse button event
$lbl_connectkey.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/#/systems/new') })
# lbl_apikey link - Mouse button event
$lbl_apikey.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://support.jumpcloud.com/support/s/article/jumpcloud-apis1') })
# move window
$Form.Add_MouseLeftButtonDown( {
        $Form.DragMove()
    })
# Put the list of profiles in the profile box
$Profiles | ForEach-Object { $lvProfileList.Items.Add($_) | Out-Null }
#===========================================================================
# Shows the form & allow move
#===========================================================================
$Form.Showdialog()
If ($bMigrateProfile.IsEnabled -eq $true)
{
# Send form results to process if $formresults & securechannel true
If (-not [System.String]::IsNullOrEmpty($formResults))
{
    Start-Migration -inputObject:($formResults)
}
Else
{
    Write-Output ('Exiting ADMU process')
}
}
