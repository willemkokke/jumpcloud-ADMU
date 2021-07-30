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
    }
    Process
    {
        if ($systemKey)
        {
            $Headers = @{
                'Accept'       = 'application/json';
                'Content-Type' = 'application/json';
                'x-api-key'    = $JcApiKey;
            }
            $Form = @{
                'filter' = "username:eq:$($JumpcloudUserName)"
            }
            Try
            {
                Write-ToLog -Message:("Getting information from SystemID: $systemKey")
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $Response = Invoke-WebRequest -Method 'Get' -Uri "https://console.jumpcloud.com/api/systemusers" -Headers $Headers -Body $Form -UseBasicParsing
                $StatusCode = $Response.StatusCode
            }
            catch
            {
                $StatusCode = $_.Exception.Response.StatusCode.value__
            }
            # Get Results, convert from Json
            $Results = $Response.Content | ConvertFrom-JSON
            $JcUserId = $Results.results.id
            # Bind Step
            if ($JcUserId)
            {
                $Headers = @{
                    'Accept'    = 'application/json';
                    'x-api-key' = $JcApiKey
                }
                $Form = @{
                    'op'   = 'add';
                    'type' = 'system';
                    'id'   = "$systemKey"
                } | ConvertTo-Json
                Try
                {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $Response = Invoke-WebRequest -Method 'Post' -Uri "https://console.jumpcloud.com/api/v2/users/$JcUserId/associations" -Headers $Headers -Body $Form -ContentType 'application/json' -UseBasicParsing
                    $StatusCode = $Response.StatusCode
                }
                catch
                {
                    $StatusCode = $_.Exception.Response.StatusCode.value__
                }
            }
            else
            {
                Write-ToLog -Message:("Cound not bind user/ JumpCloudUsername did not exist in JC Directory")
            }
        }
        else
        {
            Write-ToLog -Message:("Could not find systemKey, aborting bind step")
        }
    }
    End
    {
    }
}
function CheckUsernameorSID
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
        $registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        $list = @()
        foreach ($profile in $registyProfiles)
        {
            $list += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
        }
        if (![regex]::IsMatch($usernameorsid, $sidPattern))
        {
            $usernameorsid = (New-Object System.Security.Principal.NTAccount($usernameorsid)).Translate( [System.Security.Principal.SecurityIdentifier]).Value
            write-host "Attempting to convert user to sid..."
        }
    }
    process
    {
        if ($usernameorsid -in $list.PSChildName)
        {
            write-host "Valid SID returning SID"
            return $usernameorsid
        }
        else
        {
            Write-host "Could not find SID on this system, exiting..."
            exit
        }
    }
}
function DenyInteractiveLogonRight
{
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $SID
    )
    process{
        # Add migrating user to deny logon rights
        $secpolFile = "$WindowsDrive\Windows\temp\ur_orig.inf"
        if (Test-Path $secpolFile)
        {
            Remove-Item $secpolFile -Force
        }
        secedit /export /areas USER_RIGHTS /cfg $windowsDrive\Windows\temp\ur_orig.inf
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
function AllowInteractiveLogonRight
{
    process{
        $secpolFile = "$windowsDrive\Windows\temp\ur_orig.inf"
        secedit /configure /db secedit.sdb /cfg $secpolFile /areas USER_RIGHTS
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
        Write-Verbose "Creating user profile for $Username";
        $objUser = New-Object System.Security.Principal.NTAccount($UserName)
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $SID = $strSID.Value
        Write-Verbose "$UserName SID: $SID"
        try
        {
            $result = [UserEnvCP2]::CreateProfile($SID, $Username, $sb, $pathLen)
            if ($result -eq '-2147024713')
            {
                $status = "$userName is an existing account"
                write-verbose "$username Creation Result: $result"
            }
            elseif ($result -eq '-2147024809')
            {
                $status = "$username Not Found"
                write-verbose "$username creation result: $result"
            }
            elseif ($result -eq 0)
            {
                $status = "$username Profile has been created"
                write-verbose "$username Creation Result: $result"
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
        $status
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
            throw " Username match not found, not reversing"
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
                icacls $($UserPath) /grant administrators:F /T
                takeown /f $($UserPath) /r /d y
                Remove-Item -Path $($UserPath) -Force -Recurse
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
function Enable-Privilege
{
    param(
        ## The privilege to adjust. This set is taken from
        ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
        [ValidateSet(
            "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
            "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
            "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
            "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
            "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
            "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
            "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
            "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
            "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
            "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
            "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
        $Privilege,
        ## The process on which to adjust the privilege. Defaults to the current process.
        $ProcessId = $pid,
        ## Switch to disable the privilege, rather than enable it.
        [Switch] $Disable
    )
    ## Taken from P/Invoke.NET with minor adjustments.
    $definition = @'
 using System;
 using System.Runtime.InteropServices;
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@
    $processHandle = (Get-Process -id $ProcessId).Handle
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}
# Reg Functions adapted from:
# https://social.technet.microsoft.com/Forums/windows/en-US/9f517a39-8dc8-49d3-82b3-96671e2b6f45/powershell-set-registry-key-owner-to-the-system-user-throws-error?forum=winserverpowershell
function Get-RegKeyOwner([string]$keyPath)
{
    $regRights = [System.Security.AccessControl.RegistryRights]::ReadPermissions
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $Key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
    $acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
    $owner = $acl.GetOwner([type]::GetType([System.Security.Principal.SecurityIdentifier]))
    $key.Close()
    return $owner
}
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
function Update-RegKeyOwner([string]$keyPath, [System.Security.Principal.SecurityIdentifier]$user)
{
    try
    {
        $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
        $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
        $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
        # You must get a blank acl for the key b/c you do not currently have access
        $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
        # "Changing owner of Registry key: USERS\$keyPath to `"$user`""
        $acl.SetOwner($user)
        $key.SetAccessControl($acl)
    }
    catch
    {
        $_.Exception.toString()
        $key.Close()
        return
    }
    $key.Close()
}
function Set-FullControlToUser([System.Security.Principal.SecurityIdentifier]$userName, [string]$keyPath)
{
    # "giving full access to $userName for key $keyPath"
    $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
    # After you have set owner you need to get the acl with the perms so you can modify it.
    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($userName, "FullControl", @("ObjectInherit", "ContainerInherit"), "None", "Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)
}
function Set-ReadToUser([System.Security.Principal.SecurityIdentifier]$userName, [string]$keyPath)
{
    # "giving read access to $userName for key $keyPath"
    $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
    # After you have set owner you need to get the acl with the perms so you can modify it.
    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($userName, "ReadKey", @("ObjectInherit", "ContainerInherit"), "None", "Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)
}
function Get-AdminUserSID
{
    $windowsKey = "SOFTWARE\Microsoft\Windows"
    $regRights = [System.Security.AccessControl.RegistryRights]::ReadPermissions
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($windowsKey, $permCheck, $regRights)
    $acl = $Key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
    $owner = $acl.GetOwner([type]::GetType([System.Security.Principal.SecurityIdentifier]))
    # Return sid of owner
    return $owner.Value
}
function Set-AccessFromDomainUserToLocal
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Security.AccessControl.AccessRule]
        $accessItem,
        [Parameter()]
        [System.Security.Principal.SecurityIdentifier]
        $user,
        [Parameter()]
        [string]
        $keyPath
    )
    $regRights = [System.Security.AccessControl.RegistryRights]::takeownership
    $permCheck = [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree
    $key = [Microsoft.Win32.Registry]::Users.OpenSubKey($keyPath, $permCheck, $regRights)
    # Get Access Variables from passed in Acl.Access item
    $access = [System.Security.AccessControl.RegistryRights]$accessItem.RegistryRights
    $type = [System.Security.AccessControl.AccessControlType]$accessItem.AccessControlType
    $inheritance = [System.Security.AccessControl.InheritanceFlags]$accessItem.InheritanceFlags
    $propagation = [System.Security.AccessControl.PropagationFlags]$accessItem.PropagationFlags
    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($user, $access, $inheritance, $propagation, $type)
    # Add new Acl.Access rule to Acl so that passed in user now has access
    $acl.AddAccessRule($rule)
    # Remove the old user access
    $acl.RemoveAccessRule($accessItem) | Out-Null
    $key.SetAccessControl($acl)
}
#username To SID Function
function Get-SID ([string]$User)
{
    $objUser = New-Object System.Security.Principal.NTAccount($User)
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
    $strSID.Value
}
#Verify Domain Account Function
Function Test-Account
{
    Param (
        [Parameter(Mandatory = $true)][System.String]$userName, [System.String]$domain = $null
    )
    $idrefUser = $null
    $strUsername = $userName
    If ($domain)
    {
        $strUsername += [String]("@" + $domain)
    }
    Try
    {
        $idrefUser = ([System.Security.Principal.NTAccount]($strUsername)).Translate([System.Security.Principal.SecurityIdentifier])
    }
    Catch [System.Security.Principal.IdentityNotMappedException]
    {
        $idrefUser = $null
    }
    If ($idrefUser)
    {
        Return $true
    }
    Else
    {
        Return $false
    }
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
                REG LOAD HKU\$($UserSid)_admu "$ProfilePath\NTUSER.DAT.BAK"
                if ($?)
                {
                    Write-ToLog -Message:('Load Profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
                }
                else
                {
                    Write-ToLog -Message:('Cound not load profile: ' + "$ProfilePath\NTUSER.DAT.BAK")
                }
                Start-Sleep -Seconds 1
                REG LOAD HKU\"$($UserSid)_Classes_admu" "$ProfilePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak"
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
                REG UNLOAD HKU\$($UserSid)_admu
                if ($?)
                {
                    Write-ToLog -Message:('Unloaded Profile: ' + "$ProfilePath\NTUSER.DAT.bak")
                }
                else
                {
                    Write-ToLog -Message:('Could not unload profile: ' + "$ProfilePath\NTUSER.DAT.bak")
                }
                Start-Sleep -Seconds 1
                REG UNLOAD HKU\$($UserSid)_Classes_admu
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
            Write-ToLog "REG Keys are loaded at the end of testing, exiting..."
            exit
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
        # TODO: throw error from message above
        throw "error"
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
        Write-ToLog -Message("Could not get the profile path for $UserSid exiting...") -Level Error
        exit
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
#Download $Link to $Path
Function Invoke-DownloadFile($Link, $Path)
{
    $WebClient = New-Object -TypeName:('System.Net.WebClient')
    $IsDownloaded = $false
    $SplatArgs = @{ InputObject = $WebClient
        EventName               = 'DownloadFileCompleted'
        Action                  = @{ $IsDownloaded = $true; }
    }
    $DownloadCompletedEventSubscriber = Register-ObjectEvent @SplatArgs
    $WebClient.DownloadFileAsync("$Link", "$Path")
    While (-not $IsDownloaded)
    {
        Start-Sleep -Seconds 3
    } # While
    $DownloadCompletedEventSubscriber.Dispose()
    $WebClient.Dispose()
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
        } If ($ver.UninstallString -and $ver.DisplayName -match 'FileZilla Client 3.46.3')
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
            if ($username -match $env:computername)
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
        # Invoke-DownloadFile -Link $msvc2013x64Link -Path ($usmtTempPath + $msvc2013x64File)
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
        # Invoke-DownloadFile -Link $msvc2013x86Link -Path ($usmtTempPath + $msvc2013x86File)
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
        # Invoke-DownloadFile -Link $AGENT_INSTALLER_URL -Path $AGENT_INSTALLER_PATH
        Write-ToLog -Message:('JumpCloud Agent Download Complete')
        Write-ToLog -Message:('Running JCAgent Installer')
        #Run Installer
        # Invoke-JumpCloudAgentInstall -AgentPath $AGENT_INSTALLER_PATH -ConnectKey $JumpCloudConnectKey
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
            exit 1
        }
    }
}
function Test-RegistryAccess
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $profilePath,
        [Parameter()]
        [string]
        $userSID
    )
    begin
    {
        # Load keys
        REG LOAD HKU\"testUserAccess" "$profilePath\NTUSER.DAT" *>6
        $classes = "testUserAccess_Classes"
        # wait just a moment mountng can take a moment
        Start-Sleep 1
        REG LOAD HKU\$classes "$profilePath\AppData\Local\Microsoft\Windows\UsrClass.dat" *>6
        New-PSDrive -Name:("HKEY_USERS") -PSProvider:("Registry") -Root:("HKEY_USERS") *>6
        $HKU = Get-Acl "HKEY_USERS:\testUserAccess"
        $HKU_Classes = Get-Acl "HKEY_USERS:\testUserAccess_Classes"
        $HKUKeys = @($HKU, $HKU_Classes)
        try
        {
            $convertedSID = Convert-Sid "$userSID" -ErrorAction SilentlyContinue
        }
        catch
        {
            write-information "Could not convert user SID, testing ACLs for SID access" -InformationAction Continue
        }
    }
    process
    {
        # Check the access for the root key
        $sidAccessCount = 0
        $userAccessCount = 0
        ForEach ($rootKey in $HKUKeys.Path)
        {
            $acl = Get-Acl $rootKey
            foreach ($al in $acl.Access)
            {
                if ($al.IdentityReference -eq "$userSID")
                {
                    # write-information "ACL Access identified by SID: $userSID" -InformationAction Continue
                    $sidAccessCount += 1
                }
                elseif ($al.IdentityReference -eq $convertedSID)
                {
                    # write-information "ACL Access identified by username : $convertedSID" -InformationAction Continue
                    $userAccessCount += 1
                }
            }
        }
        if ($sidAccessCount -eq 2)
        {
            # If both root keys have been verified by sid set $accessIdentity
            write-information "Verified ACL access by SID: $userSID" -InformationAction Continue
            $accessIdentity = $userSID
        }
        if ($userAccessCount -eq 2)
        {
            # If both root keys have been verified by sid set $accessIdentity
            write-information "Verified ACL access by username: $convertedSID" -InformationAction Continue
            $accessIdentity = $convertedSID
        }
        if ([string]::ISNullorEmpty($accessIdentity))
        {
            # if failed to find user access in registry, exit
            write-information "Could not verify ACL access on root keys" -InformationAction Continue
            exit
        }
        else
        {
            # return the $identityAccess variable for registry changes later
            return $accessIdentity
        }
    }
    end
    {
        # unload the registry
        [gc]::collect()
        Start-Sleep -Seconds 1
        REG UNLOAD HKU\"testUserAccess" *>6
        # sometimes this can take a moment between unloading
        Start-Sleep -Seconds 1
        REG UNLOAD HKU\"testUserAccess_Classes" *>6
        $null = Remove-PSDrive -Name HKEY_USERS
    }
}
#endregion Functions
#region Agent Install Helper Functions
Function Test-AgentIsOnFileSystem()
{
    Test-Path -Path:(${AGENT_PATH} + '/' + ${AGENT_BINARY_NAME})
}
Function Invoke-JumpCloudAgentInstall()
{
    $params = ("${AGENT_INSTALLER_PATH}", "-k ${JumpCloudConnectKey}", "/VERYSILENT", "/NORESTART", "/SUPRESSMSGBOXES", "/NOCLOSEAPPLICATIONS", "/NORESTARTAPPLICATIONS", "/LOG=$env:TEMP\jcUpdate.log")
    Invoke-Expression "$params"
}
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
        [Parameter(ParameterSetName = 'cmd', Mandatory = $false)][bool]$AzureADProfile = $false,
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
            $SelectedUserName = $inputObject.DomainUserName
            $JumpCloudUserName = $inputObject.JumpCloudUserName
            $TempPassword = $inputObject.TempPassword
            if (($inputObject.JumpCloudConnectKey).Length -eq 40)
            {
                $JumpCloudConnectKey = $inputObject.JumpCloudConnectKey
            }
            $InstallJCAgent = $inputObject.InstallJCAgent
            $AutobindJCUser = $inputObject.AutobindJCUser
            $LeaveDomain = $InputObject.LeaveDomain
            $ForceReboot = $InputObject.ForceReboot
            $UpdateHomePath = $inputObject.UpdateHomePath
            $netBiosName = $inputObject.NetBiosName
            $displayGuiPrompt = $true
        }
        else
        {
            $netBiosName = Get-NetBiosName
        }
        # Define misc static variables
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
        # JumpCloud Agent Installation Variables
        $AGENT_PATH = "${env:ProgramFiles}\JumpCloud"
        # $AGENT_CONF_FILE = "\Plugins\Contrib\jcagent.conf"
        $AGENT_BINARY_NAME = "JumpCloud-agent.exe"
        # $AGENT_SERVICE_NAME = "JumpCloud-agent"
        $AGENT_INSTALLER_URL = "https://s3.amazonaws.com/jumpcloud-windows-agent/production/JumpCloudInstaller.exe"
        $AGENT_INSTALLER_PATH = "$windowsDrive\windows\Temp\JCADMU\JumpCloudInstaller.exe"
        # $AGENT_UNINSTALLER_NAME = "unins000.exe"
        # $EVENT_LOGGER_KEY_NAME = "hklm:\SYSTEM\CurrentControlSet\services\eventlog\Application\JumpCloud-agent"
        # $INSTALLER_BINARY_NAMES = "JumpCloudInstaller.exe,JumpCloudInstaller.tmp"
        # Track migration steps
        $admuTracker = [Ordered]@{
            backup              = @{'pass' = $false; 'fail' = $false }
            newUserInit         = @{'pass' = $false; 'fail' = $false }
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
        }
        Write-ToLog -Message("The Selected Migration user is: $SelectedUserName")
        $SelectedUserSid = Test-UsernameOrSID $SelectedUserName
        Write-ToLog -Message:('Creating JCADMU Temporary Path in ' + $jcAdmuTempPath)
        if (!(Test-path $jcAdmuTempPath))
        {
            new-item -ItemType Directory -Force -Path $jcAdmuTempPath 2>&1 | Write-Verbose
        }
        # Test checks
        if ($AzureADProfile -eq $true -or $netBiosName -match 'AzureAD')
        {
            $DomainName = 'AzureAD'
            $netBiosName = 'AzureAD'
            Write-ToLog -Message:($localComputerName + ' is currently Domain joined and $AzureADProfile = $true')
        }
        elseif ($AzureADProfile -eq $false)
        {
            $DomainName = $WmiComputerSystem.Domain
            $netBiosName = Get-NetBiosName
            Write-ToLog -Message:($localComputerName + ' is currently Domain joined to ' + $DomainName + ' NetBiosName is ' + $netBiosName)
        }
        #endregion Test checks
        # Check User Shell Paths
        $oldUserProfileImagePath = Get-ItemPropertyValue -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath'
        #TODO: move regload/unload test into begin block from below
        Set-UserRegistryLoadState -op "Unload" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSid
        Set-UserRegistryLoadState -op "Load" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSid
        $mountedreg = 'HCU:\' + $SelectedUserSid + '_admu' + '\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        Test-RegistryValueMatch -Path $mountedreg -Value 'Templates' -stringmatch $oldUserProfileImagePath
        Set-UserRegistryLoadState -op "Unload" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSid
        #endregion Check User Shell Paths
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
            $admuTracker.backup.fail = $true
            return
        }
        $admuTracker.backup.pass = $true
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
            $admuTracker.newUserInit.fail = $true
            return
        }
        # Initialize the Profile
        New-LocalUserProfile -username $JumpCloudUserName -ErrorVariable profileInit
        if ($profileInit)
        {
            Write-ToLog -Message:("$profileInit")
            Write-ToLog -Message:("The user: $JumpCloudUserName could not be initalized, exiting")
            $admuTracker.newUserInit.fail = $true
            return
        }
        $admuTracker.newUserInit.pass = $true
        ### End Create New User Region ###
        ### Begin Regedit Block ###
        Write-ToLog -Message:('Getting new profile image path')
        # Set the New User Profile Path
        # Now get NewUserSID
        $NewUserSID = Get-SID -User $JumpCloudUserName
        # Get profile image path for new user
        $newUserProfileImagePath = Get-ProfileImagePath -UserSid $NewUserSID
        ### Begin backup user registry for new user
        if ([System.String]::IsNullOrEmpty($newUserProfileImagePath))
        {
            Write-ToLog -Message("Could not get the profile path for $jumpcloudusername exiting...")
            exit 1
        }
        # backup new user registry hives
        try
        {
            Backup-RegistryHive -profileImagePath $newUserProfileImagePath
            ### End backup user registry for new user
        }
        catch
        {
            Write-ToLog -Message("Could Not Backup Registry Hives in $($newUserProfileImagePath): Exiting...")
            Write-ToLog -Message($_.Exception.Message)
            exit 1
        }
        # Test Registry Access before edits
        Write-ToLog -Message:('Verifying Registry Hives can be loaded and unloaded')
        try
        {
            Test-UserRegistryLoadState -ProfilePath $newUserProfileImagePath -UserSid $newUserSid
            Test-UserRegistryLoadState -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSID
        }
        catch
        {
            Write-ToLog -Message:('Count not load and unload registry of migration user, exiting')
            exit 1
        }
        # End Test Registry
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
        # $acl_updated = Get-Acl ($newUserProfileImagePath)
        # Write-ToLog -Message:("Updated ACLs: $($acl_updated.access)")
        Write-ToLog -Message:('New User Profile Path: ' + $newUserProfileImagePath + ' New User SID: ' + $NewUserSID)
        Write-ToLog -Message:('Old User Profile Path: ' + $oldUserProfileImagePath + ' Old User SID: ' + $SelectedUserSID)
        # Load New User Profile Registry Keys
        Set-UserRegistryLoadState -op "Load" -ProfilePath $newUserProfileImagePath -UserSid $NewUserSID
        # Load Selected User Profile Keys
        Set-UserRegistryLoadState -op "Load" -ProfilePath $oldUserProfileImagePath -UserSid $SelectedUserSID
        # Copy from "SelectedUser" to "NewUser"
        # TODO: Turn this into a function
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
        #TODO: Turn this into a function
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
        # TODO: test Key exists, non terminating error here if we can't set Active Setup Keys
        # $admuTracker.activeSetupHKU = $true
        # Set the trigger to reset Appx Packages on first login
        $ADMUKEY = "HKEY_USERS:\$($newusersid)_admu\SOFTWARE\JCADMU"
        if (Get-Item $ADMUKEY -ErrorAction SilentlyContinue)
        {
            # If the registry Key exists (it wont)
            Write-ToLog "The Key Already Exists"
        }
        else
        {
            # Create the new key & remind add tracking from previous domain account for reversion if necessary
            New-RegKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU"
            Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousSID" -value "$SelectedUserSID" -regValueKind String
            Set-ValueToKey -registryRoot Users -keyPath "$($newusersid)_admu\SOFTWARE\JCADMU" -Name "previousProfilePath" -value "$oldUserProfileImagePath" -regValueKind String
        }
        # TODO: test Key exists, non terminating error here if we can't set previous SID/ ProfilePath
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
        Write-ToLog -Message:('Copy orig. ntuser.dat to ntuser_original.dat (backup reg step)')
        try
        {
            Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT" -NewName "$oldUserProfileImagePath\NTUSER_original.DAT" -Force -ErrorAction Stop
            Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -Force -ErrorAction Stop
        }
        catch
        {
            Write-ToLog -Message("Could not rename origional registry files for backup purposes: Exiting...")
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
                    exit 1
                }
            }
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
        # TODO: test and note error if failure
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
        # load registry items back for the last time.
        # TODO: remove load step
        # Set-UserRegistryLoadState -op "Load" -ProfilePath $newUserProfileImagePath -UserSid $NewUserSID
        # Unload the Reg Hives
        # Set-UserRegistryLoadState -op "Unload" -ProfilePath $newUserProfileImagePath -UserSid $NewUserSID
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
            BindUsernameToJCSystem -JcApiKey $JumpCloudAPIKey -JumpCloudUserName $JumpCloudUserName
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
                        Write-ToLog -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
                        # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
                        # Exit;
                        # $admuTracker.leaveDomain.fail = $true
                        # return
                        # TODO: exit?
                        Exit;
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
                    Write-ToLog -Message:('Unable to leave domain, JumpCloud agent will not start until resolved') -Level:('Error')
                    # TODO: instead of exit, return and note the error in the logs (Non Terminating?)
                    # Exit;
                    # $admuTracker.leaveDomain.fail = $true
                    # return
                    # TODO: exit?
                    Exit;
                }
            }
            $admuTracker.leaveDomain.pass = $true
        }
        # Cleanup Folders Again Before Reboot
        Write-ToLog -Message:('Removing Temp Files & Folders.')
        Start-Sleep -s 10
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
                            }
                            catch
                            {
                                Write-ToLog -Message:("Could not remove the $JumpCloudUserName profile and user account") -Level Error
                            }
                            $FixedErrors += "$trackedStep"
                        }
                        'renameOriginalFiles'
                        {
                            Write-ToLog -Message:("Attempting to revert $($trackedStep) steps")
                            ### Should we be using Rename-Item here or Move-Item to force overwrite?
                            if (Test-Path "$oldUserProfileImagePath\NTUSER_original.DAT" -PathType Leaf)
                            {
                                try
                                {
                                    Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT" -NewName "$oldUserProfileImagePath\NTUSER_failedCopy.DAT" -Force -ErrorAction Stop
                                    Rename-Item -Path "$oldUserProfileImagePath\NTUSER_original.DAT" -NewName "$oldUserProfileImagePath\NTUSER.DAT" -Force -ErrorAction Stop
                                }
                                catch
                                {
                                    Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\NTUSER_original.DAT") -Level Error
                                }
                            }
                            if (Test-Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -PathType Leaf)
                            {
                                try
                                {
                                    Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_failedCopy.dat" -Force -ErrorAction Stop
                                    Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
                                }
                                catch
                                {
                                    Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass_original.dat") -Level Error
                                }
                                $FixedErrors += "$trackedStep"
                            }
                        }
                        'renameBackupFiles'
                        {
                            Write-ToLog -Message:("Attempting to revert $($trackedStep) steps")
                            if (Test-Path "$oldUserProfileImagePath\NTUSER.DAT.BAK" -PathType Leaf)
                            {
                                try
                                {
                                    Rename-Item -Path "$oldUserProfileImagePath\NTUSER.DAT.BAK" -NewName "$oldUserProfileImagePath\NTUSER.DAT" -Force -ErrorAction Stop
                                }
                                catch
                                {
                                    Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\NTUSER.DAT.BAK") -Level Error
                                }
                            }
                            if (Test-Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -PathType Leaf)
                            {
                                try
                                {
                                    Rename-Item -Path "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak" -NewName "$oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat" -Force -ErrorAction Stop
                                }
                                catch
                                {
                                    Write-ToLog -Message:("Unable to rename file $oldUserProfileImagePath\AppData\Local\Microsoft\Windows\UsrClass.dat.bak") -Level Error
                                }
                            }
                            $FixedErrors += "$trackedStep"
                        }
                        'renameHomeDirectory'
                        {
                            try
                            {
                                Write-ToLog -Message:("Attempting to revert RenameHomeDirectory steps")
                                if (($userCompare -ne $selectedUserName) -and (test-path -Path $newUserProfileImagePath))
                                {
                                    # Error Action stop to treat as terminating error
                                    Rename-Item -Path ($newUserProfileImagePath) -NewName ($selectedUserName) -ErrorAction Stop
                                }
                                Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $SelectedUserSID) -Name 'ProfileImagePath' -Value "$($oldUserProfileImagePath)"
                            }
                            catch
                            {
                                Write-ToLog -Message:("Unable to restore old user profile path and profile image path.") -Level Error
                            }
                            $FixedErrors += "$trackedStep"
                        }
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
            # TODO: update tool options with valid params
            Write-ToLog -Message:('Script finished successfully; Log file location: ' + $jcAdmuLogFile)
            Write-ToLog -Message:('Tool options chosen were : ' + 'Install JC Agent = ' + $InstallJCAgent + ', Leave Domain = ' + $LeaveDomain + ', Force Reboot = ' + $ForceReboot + ', AzureADProfile = ' + $AzureADProfile + ', Create System Restore Point = ' + $CreateRestore)
            if ($displayGuiPrompt){
                Show-Result -domainUser $SelectedUserName $ -localUser "$($localComputerName)\$($JumpCloudUserName)" -success $true -profilePath $newUserProfileImagePath -logPath $jcAdmuLogFile
            }
        }
        else
        {
            Write-ToLog -Message:("ADMU encoutered the following errors: $($admuTracker.Keys | Where-Object { $admuTracker[$_].fail -eq $true })") -Level Warn
            Write-ToLog -Message:("The following migration steps were reverted to their original state: $FixedErrors") -Level Warn
            if ($displayGuiPrompt){
                Show-Result -domainUser $SelectedUserName $ -localUser "$($localComputerName)\$($JumpCloudUserName)" -success $false -profilePath $newUserProfileImagePath -admuTrackerInput $admuTracker -FixedErrors $FixedErrors -logPath $jcAdmuLogFile
            }
            throw "JumpCloud ADMU was unable to migrate $selectedUserName"
        }
    }
}
# Load form
Write-ToLog 'Loading Jumpcloud ADMU. Please Wait.. Loading ADMU GUI..'
#==============================================================================================
# XAML Code - Imported from Visual Studio WPF Application
#==============================================================================================
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[xml]$XAML = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="JumpCloud ADMU 2.0.0" Height="500" Width="1000"
        WindowStyle="None"
        ResizeMode="NoResize"
        Background="White">
    <Grid Margin="0,0,0,10">
        <Grid.RowDefinitions>
            <RowDefinition Height="25"/>
            <RowDefinition/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
        </Grid.ColumnDefinitions>
        <Grid Row="0"
              Background="#0F0F2D"
              Grid.ColumnSpan="1">
            <Button x:Name="btn_close" Content="X"  VerticalAlignment="Center" Width="24" Height="25" Margin="976,0,0,0"/>
        </Grid>
        <ListView x:Name="lvProfileList" Margin="10,109,10,171" Grid.Row="1">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="System Accounts" DisplayMemberBinding="{Binding UserName}" Width="220"/>
                    <GridViewColumn Header="Last Login" DisplayMemberBinding="{Binding LastLogin}" Width="135"/>
                    <GridViewColumn Header="Currently Active" DisplayMemberBinding="{Binding Loaded}" Width="145" />
                    <GridViewColumn Header="Local Admin" DisplayMemberBinding="{Binding IsLocalAdmin}" Width="115"/>
                    <GridViewColumn Header="Local Path" DisplayMemberBinding="{Binding LocalPath}" Width="225"/>
                </GridView>
            </ListView.View>
        </ListView>
        <GroupBox Header="System Migration Options" Width="502" FontWeight="Bold" HorizontalAlignment="Left" Margin="11,305,0,10" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="125" Margin="2,0,0,0" VerticalAlignment="Top" Width="490">
                <Label Content="JumpCloud Connect Key :" HorizontalAlignment="Left" Margin="3,8,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/#/systems/new" ToolTip="https://console.jumpcloud.com/#/systems/new" FontWeight="Normal"/>
                <TextBox x:Name="tbJumpCloudConnectKey" HorizontalAlignment="Left" Height="23" Margin="149,10,0,0" Text="Enter JumpCloud Connect Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox x:Name="cb_installjcagent" Content="Install JCAgent" HorizontalAlignment="Left" Margin="123,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox x:Name="cb_leavedomain" Content="Leave Domain" HorizontalAlignment="Left" Margin="10,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <CheckBox x:Name="cb_forcereboot" Content="Force Reboot" HorizontalAlignment="Left" Margin="10,76,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                <Label Content="JumpCloud API Key :" HorizontalAlignment="Left" Margin="3,34,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/" ToolTip="https://console.jumpcloud.com/" FontWeight="Normal"/>
                <TextBox x:Name="tbJumpCloudAPIKey" HorizontalAlignment="Left" Height="23" Margin="149,40,0,0" Text="Enter JumpCloud API Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                <CheckBox x:Name="cb_autobindjcuser" Content="Autobind JC User" HorizontalAlignment="Left" Margin="123,98,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
            </Grid>
        </GroupBox>
        <GroupBox Header="Account Migration Information" Height="92" FontWeight="Bold" Margin="518,305,10,68" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="66" Margin="1,0,0,0" VerticalAlignment="Top" Width="461">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="23*"/>
                    <ColumnDefinition Width="129*"/>
                    <ColumnDefinition Width="303*"/>
                </Grid.ColumnDefinitions>
                <Label Content="Local Account Username :" HorizontalAlignment="Left" Margin="0,8,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <Label Content="Local Account Password :" HorizontalAlignment="Left" Margin="0,36,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                <TextBox x:Name="tbJumpCloudUserName" HorizontalAlignment="Left" Height="23" Margin="127,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="282" Text="Username should match JumpCloud username" Background="#FFC6CBCF" FontWeight="Bold" Grid.Column="1" Grid.ColumnSpan="2" />
                <TextBox x:Name="tbTempPassword" HorizontalAlignment="Left" Height="23" Margin="128,39,0,0" TextWrapping="Wrap" Text="Temp123!Temp123!" VerticalAlignment="Top" Width="200" FontWeight="Normal" Grid.Column="1" Grid.ColumnSpan="2"/>
            </Grid>
        </GroupBox>
        <GroupBox Header="System Information" FontWeight="Bold" Margin="376,0,10,363" Grid.Row="1">
            <Grid HorizontalAlignment="Left" Height="80" Margin="10,0,0,0" VerticalAlignment="Center" Width="594">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="125"/>
                    <ColumnDefinition Width="125"/>
                    <ColumnDefinition Width="125*"/>
                    <ColumnDefinition Width="125*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                    <RowDefinition Height="25"/>
                </Grid.RowDefinitions>
                <Label Content="Computer Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="0" />
                <Label Content="Domain Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="1" />
                <Label Content="NetBios Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="0" Grid.ColumnSpan="1" Grid.Row="2" />
                <Label Content="AzureAD Joined:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="2" Grid.ColumnSpan="1" Grid.Row="0" />
                <Label Content="Tenant Name:" HorizontalAlignment="Left" Margin="0,0,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.Column="2" Grid.ColumnSpan="1" Grid.Row="1"/>
                <Label x:Name="lbTenantName" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="1"/>
                <Label x:Name="lbAzureAD_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="0"/>
                <Label x:Name="lbComputerName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="0"/>
                <Label x:Name="lbDomainName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="1"/>
                <Label x:Name="lbNetBios" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="2"/>
            </Grid>
        </GroupBox>
        <Button x:Name="bDeleteProfile" Content="Select Profile" Height="23" IsEnabled="False" Margin="769,432,10,10" Grid.Row="1">
            <Button.Effect>
                <DropShadowEffect/>
            </Button.Effect>
        </Button>
        <Image
            Source="https://jumpcloud.com/wp-content/themes/jumpcloud/assets/images/jumpcloud-press-kit/logos/01-combination-mark-color.png" Margin="-30,12,589,363" Grid.RowSpan="2"/>
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
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }
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
$lbsecurechannel.Content = $securechannelstatus
#AzureADInformation
$lbAzureAD_Joined.Content = $AzureADStatus
$lbWorkplace_Joined.Content = $Workplace_join
$lbTenantName.Content = $TenantName
Function Test-Button([object]$tbJumpCloudUserName, [object]$tbJumpCloudConnectKey, [object]$tbTempPassword, [object]$lvProfileList, [object]$tbJumpCloudAPIKey)
{
    If (![System.String]::IsNullOrEmpty($lvProfileList.SelectedItem.UserName))
    {
        If (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true))`
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text) -and ($cb_installjcagent.IsChecked -eq $true) -and ($cb_autobindjcuser.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text) -and ($cb_autobindjcuser.IsChecked -eq $true) -and ($cb_installjcagent.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif (!(Test-IsNotEmpty $tbJumpCloudUserName.Text) -and (Test-HasNoSpace $tbJumpCloudUserName.Text) `
                -and ($cb_installjcagent.IsChecked -eq $false) -and ($cb_autobindjcuser.IsChecked -eq $false)`
                -and !(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)`
                -and !($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name)`
                -and !(Test-Localusername $tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif (($lvProfileList.selectedItem.Username -match $WmiComputerSystem.Name) -or ($lvProfileList.selectedItem.Username -eq 'UNKNOWN ACCOUNT'))
        {
            $script:bDeleteProfile.Content = "Select Domain Profile"
            $script:bDeleteProfile.IsEnabled = $false
            Return $false
        }
        Else
        {
            $script:bDeleteProfile.Content = "Correct Errors"
            $script:bDeleteProfile.IsEnabled = $false
            Return $false
        }
    }
    Else
    {
        $script:bDeleteProfile.Content = "Select Profile"
        $script:bDeleteProfile.IsEnabled = $false
        Return $false
    }
}
## Form changes & interactions
# Verbose checkbox
$cb_verbose.Add_Checked( { $VerbosePreference = 'Continue' })
# Install JCAgent checkbox
$script:InstallJCAgent = $false
$cb_installjcagent.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Checked( { $script:InstallJCAgent = $true })
$cb_installjcagent.Add_Checked( { $tbJumpCloudConnectKey.IsEnabled = $true })
$cb_installjcagent.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_installjcagent.Add_Unchecked( { $script:InstallJCAgent = $false })
$cb_installjcagent.Add_Unchecked( { $tbJumpCloudConnectKey.IsEnabled = $false })
# Autobind JC User checkbox
$script:AutobindJCUser = $false
$cb_autobindjcuser.Add_Checked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Checked( { $script:AutobindJCUser = $true })
$cb_autobindjcuser.Add_Checked( { $tbJumpCloudAPIKey.IsEnabled = $true })
$cb_autobindjcuser.Add_UnChecked( { Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey) })
$cb_autobindjcuser.Add_Unchecked( { $script:AutobindJCUser = $false })
$cb_autobindjcuser.Add_Unchecked( { $tbJumpCloudAPIKey.IsEnabled = $false })
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
            $tbJumpCloudUserName.Tooltip = "Local account user name can not be empty, contain spaces or already exist on the local system."
        }
        Else
        {
            $tbJumpCloudUserName.Background = "white"
            $tbJumpCloudUserName.Tooltip = $null
            $tbJumpCloudUserName.FontWeight = "Normal"
        }
    })
$tbJumpCloudUserName.add_GotFocus( {
        $tbJumpCloudUserName.Text = ""
    })
$tbJumpCloudConnectKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudConnectKey.Text) -and (Test-HasNoSpace $tbJumpCloudConnectKey.Text)) -eq $false)
        {
            $tbJumpCloudConnectKey.Background = "#FFC6CBCF"
            $tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        }
        Else
        {
            $tbJumpCloudConnectKey.Background = "white"
            $tbJumpCloudConnectKey.Tooltip = $null
            $tbJumpCloudConnectKey.FontWeight = "Normal"
        }
    })
$tbJumpCloudAPIKey.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbJumpCloudConnectAPIKey:($tbJumpCloudAPIKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If (((Test-Is40chars $tbJumpCloudAPIKey.Text) -and (Test-HasNoSpace $tbJumpCloudAPIKey.Text)) -eq $false)
        {
            $tbJumpCloudAPIKey.Background = "#FFC6CBCF"
            $tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
        }
        Else
        {
            $tbJumpCloudAPIKey.Background = "white"
            $tbJumpCloudAPIKey.Tooltip = $null
            $tbJumpCloudAPIKey.FontWeight = "Normal"
        }
    })
$tbJumpCloudConnectKey.add_GotFocus( {
        $tbJumpCloudConnectKey.Text = ""
    })
$tbJumpCloudAPIKey.add_GotFocus( {
        $tbJumpCloudAPIKey.Text = ""
    })
$tbTempPassword.add_TextChanged( {
        Test-Button -tbJumpCloudUserName:($tbJumpCloudUserName) -tbJumpCloudConnectKey:($tbJumpCloudConnectKey) -tbTempPassword:($tbTempPassword) -lvProfileList:($lvProfileList) -tbJumpCloudAPIKey:($tbJumpCloudAPIKey)
        If ((!(Test-IsNotEmpty $tbTempPassword.Text) -and (Test-HasNoSpace $tbTempPassword.Text)) -eq $false)
        {
            $tbTempPassword.Background = "#FFC6CBCF"
            $tbTempPassword.Tooltip = "Temp Password Must Not Be Empty & Not Contain Spaces"
        }
        Else
        {
            $tbTempPassword.Background = "white"
            $tbTempPassword.Tooltip = $null
            $tbTempPassword.FontWeight = "Normal"
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
            $script:bDeleteProfile.Content = "User Registry Loaded"
            $script:bDeleteProfile.IsEnabled = $false
            $script:tbJumpCloudUserName.IsEnabled = $false
            $script:tbTempPassword.IsEnabled = $false
        }
        else
        {
            $script:tbJumpCloudUserName.IsEnabled = $true
            $script:tbTempPassword.IsEnabled = $true
        }
    })
$bDeleteProfile.Add_Click( {
        # Build FormResults object
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('InstallJCAgent') -Value:($InstallJCAgent)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('AutobindJCUser') -Value:($AutobindJCUser)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('LeaveDomain') -Value:($LeaveDomain)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('ForceReboot') -Value:($ForceReboot)
        # Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName.Substring($SelectedUserName.IndexOf('\') + 1))
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudUserName') -Value:($tbJumpCloudUserName.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('TempPassword') -Value:($tbTempPassword.Text)
        if (($tbJumpCloudConnectKey.Text).length -eq 40)
        {
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($tbJumpCloudConnectKey.Text)
        }
        if (($tbJumpCloudAPIKey.Text).length -eq 40)
        {
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudAPIKey') -Value:($tbJumpCloudAPIKey.Text)
        }
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('NetBiosName') -Value:($SelectedUserName)
        # Close form
        $Form.Close()
    })
# JCConsole Link
$tbjcconsole.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/login') })
# JCADMUGH Link
$tbjcadmugh.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://github.com/TheJumpCloud/jumpcloud-ADMU') })
# JCSupport Link
$tbjcsupport.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://support.jumpcloud.com/support/s/') })
# jcadmulog
$tbjcadmulog.Add_PreviewMouseDown( { Invoke-Item "C:\Windows\Temp\JCADMU.log" })
# close button
$btn_close.Add_Click( {
        $Form.Close()
    })
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
If ($bDeleteProfile.IsEnabled -eq $true)
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
