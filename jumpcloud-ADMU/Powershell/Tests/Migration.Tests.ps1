BeforeAll{
    # import build variables for test cases
    write-host "Importing Build Variables:"
    . $PSScriptRoot\BuildVariables.ps1
    # import functions from start migration
    write-host "Importing Start-Migration Script:"
    . $PSScriptRoot\..\Start-Migration.ps1
    # setup tests (This creates any of the users in the build vars dictionary)
    write-host "Running SetupAgent Script:"
    . $PSScriptRoot\SetupAgent.ps1

    $config = get-content 'C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf'
    $regex = 'systemKey\":\"(\w+)\"'
    $systemKey = [regex]::Match($config, $regex).Groups[1].Value
}
Describe 'Migration Test Scenarios'{
    Context 'Start-Migration on local accounts (Test Functionallity)' {
        BeforeEach{
            # Remove the log from previous runs
            $logPath = "C:\Windows\Temp\jcadmu.log"
            Remove-Item $logPath
            New-Item $logPath -Force -ItemType File
        }
        It "username extists for testing" {
            foreach ($user in $userTestingHash.Values){
                $user.username | Should -Not -BeNullOrEmpty
                $user.JCusername | Should -Not -BeNullOrEmpty
                Get-LocalUser $user.username | Should -Not -BeNullOrEmpty
            }
        }
        It "Test Convert profile migration for Local users" {
            foreach ($user in $userTestingHash.Values)
            {
                # write-host "Running: Start-Migration -JumpCloudUserName $($user.JCUsername) -SelectedUserName $($user.username) -TempPassword $($user.password)"
                write-host "`nRunning: Start-Migration -JumpCloudUserName $($user.JCUsername) -SelectedUserName $($user.username) -TempPassword $($user.password)`n"
                # Invoke-Command -ScriptBlock { Start-Migration -JumpCloudUserName "$($user.JCUsername)" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -ConvertProfile $true} | Should -Not -Throw
                { Start-Migration -JumpCloudUserName "$($user.JCUsername)" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -UpdateHomePath $user.UpdateHomePath} | Should -Not -Throw
            }
        }
        It "Test UWP_JCADMU was downloaded & exists"{
            Test-Path "C:\Windows\uwp_jcadmu.exe" | Should -Be $true
        }
        It "Test Converted User Home Attribues"{
            foreach ($user in $userTestingHash.Values){
                if ($user.UpdateHomePath){
                    $UserHome = "C:\Users\$($user.JCUsername)"
                }
                else {
                    $UserHome = "C:\Users\$($user.Username)"
                }
                # User Home Directory Should Exist
                Test-Path "$UserHome" | Should -Be $true
                # Backup Registry & Registry Files Should Exist
                Test-Path "$UserHome/NTUSER_original.DAT" | Should -Be $true
                Test-Path "$UserHome/NTUSER.DAT" | Should -Be $true
                Test-Path "$UserHome/AppData/Local/Microsoft/Windows/UsrClass.DAT" | Should -Be $true
                Test-Path "$UserHome/AppData/Local/Microsoft/Windows/UsrClass_original.DAT" | Should -Be $true
            }
        }
    }
    Context 'Start-Migration on Local Accounts Expecting Failed Results (Test Reversal Functionallity)' {
        BeforeEach {
            # Remove the log from previous runs
            $logPath = "C:\Windows\Temp\jcadmu.log"
            Remove-Item $logPath
            New-Item $logPath -Force -ItemType File
        }
        It "Start-Migration remove the new user created if it encounters an error" {
            foreach ($user in $JCReversionHash.Values) {
                # Begin job to watch start-migration
                $waitJob = Start-Job -ScriptBlock:( {
                        [CmdletBinding()]
                        param (
                            [Parameter()]
                            [string]
                            $UserName
                        )
                        $path = "C:\Users\$UserName"
                        $file = "$path\NTUSER.DAT"
                        $fileExists = $false
                        while (!$fileExists)
                        {
                            if (Test-Path $file)
                            {
                                Write-Host "Found: $file"
                                try{
                                    Write-Host "Attempting to Rename File: $file"
                                    Rename-Item -Path $file -NewName "$path\MESSUP.DAT" -Force -ErrorAction Stop
                                    $fileExists = $true
                                }
                                catch{
                                    Write-Host "File in use"
                                }
                            }
                        }
                        # $waitCondition = $false
                        # while (!$waitCondition)
                        # {
                        #     $content = Get-Content $LogFile
                        #     if ($content -match $logString)
                        #     {
                        #         Write-Host "Found Match in Log: $logString"
                        #         $waitCondition = $true
                        #     }
                        # }
                        Write-Host "Rename NTUser to throw migration process"
                        # Watch the log; break when we see expected string
                        Rename-Item -Path $file -NewName "$path\MESSUP.DAT" -ErrorVariable renameError
                        if ($renameError){
                            Write-Host "Could not rename item for some reason, this test will have failed by the time you see this message"
                        }
                        if (Test-Path "$path\MESSUP.DAT"){
                            Write-Host "Renamed NTUser.dat file the process should fail"
                        }
                        Write-Host "Job Completed"
                    }) -ArgumentList:($($user.JCUsername))
                # Begin job to kick off startMigration
                write-host "`nRunning: Start-Migration -JumpCloudUserName $($user.JCUsername) -SelectedUserName $($user.username) -TempPassword $($user.password)`n"
                { Start-Migration -JumpCloudAPIKey $env:JCApiKey -AutobindJCUser $false -JumpCloudUserName "$($user.JCUsername)" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -UpdateHomePath $user.UpdateHomePath } | Should -Throw
                # receive the wait-job
                Write-Host "Job Details:"
                Receive-Job -Job $waitJob -Keep
                # The original user should exist
                "C:\Users\$($user.username)" | Should -Exist
                # NewUserInit should be reverted and the new user profile path should not exist
                "C:\Users\$($user.JCUsername)" | Should -Not -Exist
            }
        }
        It "Start-Migration should throw if the jumpcloud user already exists & not migrate anything"{
            foreach ($user in $JCExistingHash.Values)
            {
                # attempt to migrate to user from previous step
                { Start-Migration -JumpCloudAPIKey $env:JCApiKey -AutobindJCUser $false -JumpCloudUserName "ADMU_newUserInit" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -UpdateHomePath $user.UpdateHomePath } | Should -Throw
                # The original user should exist
                "C:\Users\$($user.username)" | Should -Exist
            }
        }
        It "Start-Migration should throw if the jumpcloud user already exists & not migrate anything" -Skip{
            # TODO: Reversal should log that the user existed & delete the user after tun
        }
    }

    Context 'Start-Migration Sucessfully Binds JumpCloud User to System'{
        It 'user bound to system after migration' {
            foreach ($user in $JCFunctionalHash.Values)
            {
                $users = Get-JCSDKUser
                if ("$($user.JCUsername)" -in $users.Username){
                    $existing = $users | Where-Object { $_.username -eq "$($user.JCUsername)"}
                    Write-Host "Found JumpCloud User, $($existing.Id) removing..."
                    Remove-JcSdkUser -Id $existing.Id
                }
                $GeneratedUser = New-JcSdkUser -Email:("$($user.JCUsername)@jumpcloudadmu.com") -Username:("$($user.JCUsername)") -Password:("$($user.password)")
                write-host "`nRunning: Start-Migration -JumpCloudUserName $($user.JCUsername) -SelectedUserName $($user.username) -TempPassword $($user.password)`n"
                # Invoke-Command -ScriptBlock { Start-Migration -JumpCloudUserName "$($user.JCUsername)" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -ConvertProfile $true} | Should -Not -Throw
                { Start-Migration -JumpCloudAPIKey $env:JCApiKey -AutobindJCUser $true -JumpCloudUserName "$($user.JCUsername)" -SelectedUserName "$ENV:COMPUTERNAME\$($user.username)" -TempPassword "$($user.password)" -UpdateHomePath $user.UpdateHomePath } | Should -Not -Throw
                $associations = Get-JcSdkSystemAssociation -SystemId $systemKey -Targets user
                # GeneratedUserID should be in the associations list
                $GeneratedUser.Id | Should -BeIn $associations.ToId
                # TODO: read log/ read bound users from system and return statement
            }
        }
    }
    Context 'Start-Migration kicked off through JumpCloud agent'{
        BeforeAll{
            # test connection to Org
            $Org = Get-JcSdkOrganization
            Write-Host "Connected to Pester Org: $($Org.DisplayName)"
            # Get System Key
            $config = get-content 'C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf'
            $regex = 'systemKey\":\"(\w+)\"'
            $systemKey = [regex]::Match($config, $regex).Groups[1].Value
            Write-Host "Running Tests on SystemID: $systemKey"
            # Connect-JCOnline

            # variables for test
            $CommandBody = '
. C:\Users\circleci\project\jumpcloud-ADMU\Powershell\Start-Migration.ps1
# Trim env vars with hardcoded ""
$JCU = ${ENV:$JcUserName}.Trim([char]0x0022)
$SU = ${ENV:$SelectedUserName}.Trim([char]0x0022)
$PW = ${ENV:$TempPassword}.Trim([char]0x0022)
Start-Migration -JumpCloudUserName $JCU -SelectedUserName $ENV:COMPUTERNAME\$SU -TempPassword $PW
'
            $CommandTrigger = 'ADMU'
            $CommandName = 'RemoteADMU'
            # clear command results
            $results = Get-JcSdkCommandResult
            foreach ($result in $results)
            {
                # Delete Command Results
                Write-Host "Found Command Results: $($result.id) removing..."
                remove-jcsdkcommandresult -id $result.id
            }
            # Clear previous commands matching the name
            $RemoteADMUCommands = Get-JcSdkCommand | Where-Object { $_.name -eq $CommandName }
            foreach ($result in $RemoteADMUCommands)
            {
                # Delete Command Results
                Write-Host "Found existing Command: $($result.id) removing..."
                Remove-JcSdkCommand -id $result.id
            }

            # Create command & association to command
            New-JcSdkCommand -Command $CommandBody -CommandType "windows" -Name $CommandName -Trigger $CommandTrigger -Shell powershell
            $CommandID = (Get-JcSdkCommand | Where-Object { $_.Name -eq $CommandName }).Id
            Write-Host "Setting CommandID: $CommandID associations"
            Set-JcSdkCommandAssociation -CommandId $CommandID -Id $systemKey -Op add -Type system
        }
        It 'Test that system key exists'{
            $systemKey | Should -Not -BeNullOrEmpty
        }
        It 'Invoke ADMU from JumpCloud Command' {
            # clear results
            $results = Get-JcSdkCommandResult
            foreach ($result in $results)
            {
                # Delete Command Results
                remove-jcsdkcommandresult -id $result.id
            }
            # begin tests
            foreach ($user in $JCCommandTestingHash.Values) {
                write-host "Running: Start-Migration -JumpCloudUserName $($user.JCUsername) -SelectedUserName $($user.username) -TempPassword $($user.password)"
                $headers = @{
                    'Accept'    = "application/json"
                    'x-api-key' = $env:JCApiKey
                }
                $Form = @{
                    '$JcUserName'       = $user.JCUsername;
                    '$SelectedUserName' = $user.Username;
                    '$TempPassword'     = $user.Password
                } | ConvertTo-Json
                Invoke-RestMethod -Method POST -Uri "https://console.jumpcloud.com/api/command/trigger/$($CommandTrigger)" -ContentType 'application/json' -Headers $headers -Body $Form
                Write-Host "Invoke Command ADMU:"
                $count = 0
                do
                {
                    $invokeResults = Get-JcSdkCommandResult
                    Write-Host "Waiting 5 seconds for system to receive command..."
                    $count += 1
                    start-sleep 5
                } until (($invokeResults) -or ($count -eq 24))
                Write-Host "Command pushed to system, waiting on results"
                $count = 0
                do{
                    $CommandResults = Get-JcSdkCommandResult -id $invokeResults.Id
                    Write-host "Waiting 5 seconds on results..."
                    $count += 1
                    start-sleep 5
                } until ((($CommandResults.DataExitCode) -is [int]) -or ($count -eq 24))
                $CommandResults.DataExitCode | Should -Be 0
            }

        }

    }
}

AfterAll{
    $systems = Get-JCsdkSystem
    $CIsystems = $systems | Where-Object { $_.displayname -match "packer" }
    foreach ($system in $CIsystems) {
        Remove-JcSdkSystem -id $system.Id
    }
}
# New User SID should have the correct profile path
# User profile should be named correctly


# user -> username where username exists should fail and revert
# new sid should not exist
# new user folder should not exist
# old user account should have orgional NTUSER.DAT and USRCLASS.DAT files
# old user should be able to login.