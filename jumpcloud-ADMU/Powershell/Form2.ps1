Add-Type -AssemblyName 'PresentationCore', 'PresentationFramework'
#[Xml]$WpfXml = Get-Content -Path 'RunspaceGUI.xaml'

[xml]$WpfXml = @'
<Window x:Class="ADMU_v2.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:ADMU_v2"
        mc:Ignorable="d"
        Title="MainWindow" Height="994" Width="919"
        WindowStyle="None"
        ResizeMode="NoResize"
        Background="White">

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="25"/>
            <RowDefinition/>
            <RowDefinition Height="25"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition/>
            <ColumnDefinition/>
        </Grid.ColumnDefinitions>

        <Grid Row="0"
              Background="#0F0F2D" 
              Grid.ColumnSpan="2">

            <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition/>
                <ColumnDefinition/>
                <ColumnDefinition/>
            </Grid.ColumnDefinitions>

            <Button x:Name="btn_close" Content="X"  VerticalAlignment="Center" Width="24" Height="25" Grid.Column="3" Margin="206,0,0,0"/>



        </Grid>

        <Grid Row="1"
              Background="White" 
              Grid.ColumnSpan="2">

            <StackPanel Grid.Row="1" Grid.Column="1" Margin="0,0,54,710">
                <StackPanel Orientation="Horizontal">
                    <Image Width="91" Height="91"
                       Source="https://images.g2crowd.com/uploads/product/image/large_detail/large_detail_106a112f3cbf66eae385f29d407dd288/jumpcloud.png"/>
                    <Image Width="266" Height="84"
                       Source="https://jumpcloud.com/wp-content/themes/jumpcloud/assets/images/jumpcloud-press-kit/logos/05-wordmark-dark.png"/>
                </StackPanel>
            </StackPanel>

            <ListView x:Name="lvProfileList" Margin="10,148,10,649">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="System Accounts" DisplayMemberBinding="{Binding UserName}" Width="190"/>
                        <GridViewColumn Header="Last Login" DisplayMemberBinding="{Binding LastLogin}" Width="135"/>
                        <GridViewColumn Header="Currently Active" DisplayMemberBinding="{Binding Loaded}" Width="105" />
                        <GridViewColumn Header="Domain Roaming" DisplayMemberBinding="{Binding RoamingConfigured}" Width="105"/>
                        <GridViewColumn Header="Local Admin" DisplayMemberBinding="{Binding IsLocalAdmin}" Width="105"/>
                        <GridViewColumn Header="Local Path" DisplayMemberBinding="{Binding LocalPath}" Width="180"/>
                    </GridView>
                </ListView.View>
            </ListView>

            <GroupBox Header="System Migration Options"  Height="155" Width="444" FontWeight="Bold" HorizontalAlignment="Left" Margin="10,300,0,489">
                <Grid HorizontalAlignment="Left" Height="137" Margin="2,0,0,0" VerticalAlignment="Center" Width="431">
                    <Label Content="JumpCloud Connect Key :" HorizontalAlignment="Left" Margin="3,8,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/#/systems/new" ToolTip="https://console.jumpcloud.com/#/systems/new" FontWeight="Normal"/>
                    <TextBox x:Name="tbJumpCloudConnectKey" HorizontalAlignment="Left" Height="23" Margin="149,10,0,0" Text="Enter JumpCloud Connect Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                    <CheckBox x:Name="cb_installjcagent" Content="Install JCAgent" HorizontalAlignment="Left" Margin="123,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                    <CheckBox x:Name="cb_leavedomain" Content="Leave Domain" HorizontalAlignment="Left" Margin="10,108,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                    <CheckBox x:Name="cb_forcereboot" Content="Force Reboot" HorizontalAlignment="Left" Margin="10,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                    <CheckBox x:Name="cb_verbose" Content="Verbose" HorizontalAlignment="Left" Margin="249,88,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                    <Label Content="JumpCloud API Key :" HorizontalAlignment="Left" Margin="4,37,0,0" VerticalAlignment="Top" AutomationProperties.HelpText="https://console.jumpcloud.com/" ToolTip="https://console.jumpcloud.com/" FontWeight="Normal"/>
                    <TextBox x:Name="tbJumpCloudAPIKey" HorizontalAlignment="Left" Height="23" Margin="149,40,0,0" Text="Enter JumpCloud API Key" VerticalAlignment="Top" Width="271" Background="#FFC6CBCF" FontWeight="Bold" IsEnabled="False"/>
                    <CheckBox x:Name="cb_autobindjcuser" Content="Autobind JC User" HorizontalAlignment="Left" Margin="123,111,0,0" VerticalAlignment="Top" FontWeight="Normal" IsChecked="False"/>
                </Grid>
            </GroupBox>

            <GroupBox Header="Account Migration Information" Height="92" FontWeight="Bold" Margin="464,300,10,552">
                <Grid HorizontalAlignment="Left" Height="66.859" Margin="1.212,2.564,0,0" VerticalAlignment="Top" Width="454.842">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="23*"/>
                        <ColumnDefinition Width="432*"/>
                    </Grid.ColumnDefinitions>
                    <Label Content="Local Account Username :" HorizontalAlignment="Left" Margin="0,8,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                    <Label Content="Local Account Password :" HorizontalAlignment="Left" Margin="0,36,0,0" VerticalAlignment="Top" FontWeight="Normal" Grid.ColumnSpan="2"/>
                    <TextBox x:Name="tbJumpCloudUserName" HorizontalAlignment="Left" Height="23" Margin="127,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="282" Text="Username should match JumpCloud username" Background="#FFC6CBCF" FontWeight="Bold" Grid.Column="1" />
                    <TextBox x:Name="tbTempPassword" HorizontalAlignment="Left" Height="23" Margin="128,39,0,0" TextWrapping="Wrap" Text="Temp123!Temp123!" VerticalAlignment="Top" Width="200" FontWeight="Normal" Grid.Column="1"/>
                </Grid>
            </GroupBox>

            <Button x:Name="bDeleteProfile" Content="Select Profile" Height="23" IsEnabled="False" Margin="716,397,13,524">
                <Button.Effect>
                    <DropShadowEffect/>
                </Button.Effect>
            </Button>

            <GroupBox Header="System Information" Margin="336,10,13,806" Width="570" FontWeight="Bold">

                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="25"/>
                        <RowDefinition Height="25"/>
                        <RowDefinition Height="25"/>
                        <RowDefinition Height="25"/>
                    </Grid.RowDefinitions>

                    <Grid.ColumnDefinitions>
                        <ColumnDefinition/>
                        <ColumnDefinition/>
                        <ColumnDefinition/>
                        <ColumnDefinition/>
                    </Grid.ColumnDefinitions>

                    <Label Content="Computer Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="0"/>
                    <Label Content="Domain Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="1"/>
                    <Label Content="NetBios Name:" FontWeight="Normal" Grid.Column="0" Grid.Row="2"/>
                    <Label Content="Secure Channel Healthy:" FontWeight="Normal" Grid.Column="0" Grid.Row="3"/>
                    <Label x:Name="lbComputerName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="0"/>
                    <Label x:Name="lbDomainName" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="1"/>
                    <Label x:Name="lbNetBios" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="2"/>
                    <Label x:Name="lbsecurechannel" Content="" FontWeight="Normal" Grid.Column="1" Grid.Row="3"/>

                    <Label Content="AzureAD Joined:" FontWeight="Normal" Grid.Column="2" Grid.Row="0"/>
                    <Label Content="Workplace Joined:" FontWeight="Normal" Grid.Column="2" Grid.Row="1"/>
                    <Label Content="Azure Tenant Name:" FontWeight="Normal" Grid.Column="2" Grid.Row="2"/>
                    <Label x:Name="lbAzureAD_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="0"/>
                    <Label x:Name="lbWorkplace_Joined" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="1"/>
                    <Label x:Name="lbTenantName" Content="" FontWeight="Normal" Grid.Column="3" Grid.Row="2"/>

                </Grid>
            </GroupBox>

            <Button x:Name="RunButton" Content="TEST" Margin="66,798,653,119"/>
            <TextBlock x:Name="OutputStatusText" HorizontalAlignment="Left" Margin="66,773,0,0" Text="Not Running" TextWrapping="Wrap" VerticalAlignment="Top" Width="164" Height="20"/>
            <TextBox x:Name="CommandText" HorizontalAlignment="Left" Height="23" Margin="66,745,0,0" TextWrapping="Wrap" Text="Start-Sleep -s 5" VerticalAlignment="Top" Width="200" FontWeight="Normal"/>
            <TextBlock x:Name="textBlock" HorizontalAlignment="Center" Margin="0,460,0,0" Text="TextBlock" TextWrapping="Wrap" VerticalAlignment="Top" Height="235" Width="899" Background="#FF002B68" Foreground="White">
            </TextBlock>

        </Grid>

        <Grid Row="2"
              Background="#0F0F2D" 
              Grid.ColumnSpan="2">

            <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition/>
                <ColumnDefinition/>
                <ColumnDefinition/>
            </Grid.ColumnDefinitions>

            <TextBlock x:Name="tbjcconsole"
            Text="JumpCloud Console"
            Foreground="White"
            Grid.Column="0"
            VerticalAlignment="Center"
            HorizontalAlignment="Center"
            />

            <TextBlock x:Name="tbjcadmugh"
            Text="JumpCloud AMDU Github"
            Foreground="White"
            Grid.Column="1"
            VerticalAlignment="Center"
            HorizontalAlignment="Center"
            />

            <TextBlock x:Name="tbjcsupport"
            Text="JumpCloud Support"
            Foreground="White"
            Grid.Column="2"
            VerticalAlignment="Center"
            HorizontalAlignment="Center"
            />

            <TextBlock x:Name="tbjcadmulog"
            Text="JumpCloud ADMU Log"
            Foreground="White"
            Grid.Column="5"
            VerticalAlignment="Center"
            HorizontalAlignment="Center"
            />
        </Grid>

    </Grid>

</Window>
'@

# remove attributes from XML that cause problems with initializing the XAML object in Powershell
$WpfXml.Window.RemoveAttribute('x:Class')
$WpfXml.Window.RemoveAttribute('mc:Ignorable')
# initialize the XML Namespaces so they can be used later if required
$WpfNs = New-Object -TypeName Xml.XmlNamespaceManager -ArgumentList $WpfXml.NameTable
$WpfNs.AddNamespace('x', $WpfXml.DocumentElement.x)
$WpfNs.AddNamespace('d', $WpfXml.DocumentElement.d)
$WpfNs.AddNamespace('mc', $WpfXml.DocumentElement.mc)

# create a thread-safe Hashtable to pass data between the Powershell sessions/threads
$Sync = [Hashtable]::Synchronized(@{})
$Sync.Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $WpfXml))

# add a "sync" item to reference the GUI control objects to make accessing them easier
$Sync.Gui = @{}
foreach($Node in $WpfXml.SelectNodes('//*[@x:Name]', $WpfNs))
{
    # get all the XML elements that have an x:Name attribute, these will be controls we want to interact with
    $Sync.Gui.Add($Node.Name, $Sync.Window.FindName($Node.Name))
}

# create the runspace and pass the $Sync variable through
$Runspace = [RunspaceFactory]::CreateRunspace()
$Runspace.ApartmentState = [Threading.ApartmentState]::STA
$Runspace.Open()
$Runspace.SessionStateProxy.SetVariable('Sync',$Sync)
# handle the click event for the "Run" button
$Sync.Gui.RunButton.add_click({
    # create the extra Powershell session and add the script block to execute
    $global:Session = [PowerShell]::Create().AddScript({

        
        # make the $Error variable available to the parent Powershell session for debugging
        $Sync.Error = $Error
        # to access objects owned by the parent Powershell session a Dispatcher must be used
        $Sync.Window.Dispatcher.Invoke([Action]{
            # make $Command available outside this Dispatcher call to the rest of the script block
            $script:Command = $Sync.Gui.CommandText.Text
            $Sync.Gui.RunButton.IsEnabled = $false
            $Sync.Gui.OutputStatusText.Text = 'Running'
            $Sync.Gui.textBlock.Text = 'Running'
        })
        # by executing the command in this session the GUI owned by the parent session will remain responsive
        $Output = (Invoke-Expression -Command $command) | Out-String

        # now the command has executed the GUI can be updated again 
        $Sync.Window.Dispatcher.Invoke([Action]{
            $Sync.Gui.textBlock.Text = $Output
            $Sync.Gui.textBlock.Text = $Sync.Gui.textBlock.Text + $Error[0]
            $Sync.Gui.OutputStatusText.Text = 'Waiting'
            $Sync.Gui.RunButton.IsEnabled = $true
        })
    }, $true) # set the "useLocalScope" parameter for executing the script block

    # execute the code in this session
    $Session.Runspace = $Runspace
    $global:Handle = $Session.BeginInvoke()
    
})
# check if a command is still running when exiting the GUI
$Sync.Window.add_closing({
    if ($Session -ne $null -and $Handle.IsCompleted -eq $false)
    {
        [Windows.MessageBox]::Show('A command is still running.')
        # the event object is automatically passed through as $_
        $_.Cancel = $true
    }
})

# close the runspace cleanly when exiting the GUI
$Sync.Window.add_closed({
    if ($Session -ne $null) {$Session.EndInvoke($Handle)}
    $Runspace.Close()
})

##########################

# Define misc static variables

$WmiComputerSystem = Get-WmiObject -Class:('Win32_ComputerSystem')
Write-progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..' -PercentComplete 25
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Checking AzureAD Status..'
if ($WmiComputerSystem.PartOfDomain) {
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

    if([System.String]::IsNullOrEmpty($WmiComputerDomain[0].DnsForestName) -and $securechannelstatus -eq $false)
    {
        $DomainName = 'Fix Secure Channel'
    } else {
        $DomainName = [string]$WmiComputerDomain.DnsForestName
    }
        $NetBiosName = [string]$NetBiosName
}
elseif ($WmiComputerSystem.PartOfDomain -eq $false) {
    $DomainName = 'N/A'
    $NetBiosName = 'N/A'
    $securechannelstatus = 'N/A'
}
if ((Get-CimInstance Win32_OperatingSystem).Version -match '10') {
    $AzureADInfo = dsregcmd.exe /status
    foreach ($line in $AzureADInfo) {
        if ($line -match "AzureADJoined : ") {
            $AzureADStatus = ($line.trimstart('AzureADJoined : '))
        }
        if ($line -match "WorkplaceJoined : ") {
            $Workplace_join = ($line.trimstart('WorkplaceJoined : '))
        }
        if ($line -match "TenantName : ") {
            $TenantName = ($line.trimstart('WorkplaceTenantName : '))
        }
    }
}
else {
    $AzureADStatus = 'N/A'
    $Workplace_join = 'N/A'
    $TenantName = 'N/A'
}

$FormResults = [PSCustomObject]@{ }
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..' -PercentComplete 50
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Verifying Local Accounts & Group Membership..'
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..' -PercentComplete 70
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..'
# Get Valid SIDs from the Registry and build user object
$registyProfiles = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileList = @()
foreach ($profile in $registyProfiles) {
    $profileList += Get-ItemProperty -Path $profile.PSPath | Select-Object PSChildName, ProfileImagePath
}
# List to store users
$users = @()
foreach ($listItem in $profileList) {
    $sidPattern = "^S-\d-\d+-(\d+-){1,14}\d+$"
    $isValidFormat = [regex]::IsMatch($($listItem.PSChildName), $sidPattern);
    # Get Valid SIDs
    if ($isValidFormat) {
        # Populate Users List
        $users += [PSCustomObject]@{
            Name              = ConvertSID $listItem.PSChildName
            LocalPath         = $listItem.ProfileImagePath
            SID               = $listItem.PSChildName
            IsLocalAdmin      = $null
            Loaded            = $null
            RoamingConfigured = $null
            LastLogin         = $null
        }
    }
}
Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting C:\ & Local Profile Data..' -PercentComplete 75

# Get Win32 Profiles to merge data with valid SIDs
$win32UserProfiles = Get-WmiObject -Class:('Win32_UserProfile') -Property * | Where-Object { $_.Special -eq $false }
$date_format = "yyyy-MM-dd HH:mm"
foreach ($user in $users) {
    # Get Data from Win32Profile
    foreach ($win32user in $win32UserProfiles) {
        if ($($user.SID) -eq $($win32user.SID)) {
            $user.RoamingConfigured = $win32user.RoamingConfigured
            $user.Loaded = $win32user.Loaded
            if ([string]::IsNullOrEmpty($($win32user.LastUseTime))){
                $user.LastLogin = "N/A"
            }
            else{
                $user.LastLogin = [System.Management.ManagementDateTimeConverter]::ToDateTime($($win32user.LastUseTime)).ToUniversalTime().ToSTring($date_format)
            }
        }
    }
    Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Getting Local Profile Administrator Status..' -PercentComplete 80
    # Get Admin Status
    try {
        $admin = Get-LocalGroupMember -Member "$($user.SID)" -Name "Administrators" -EA SilentlyContinue
    }
    catch {
        $user = Get-LocalGroupMember -Member "$($user.SID)" -Name "Users"
    }
    if ($admin) {
        $user.IsLocalAdmin = $true
    }
    else {
        $user.IsLocalAdmin = $false
    }
}

Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..' -PercentComplete 85
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Building Profile Group Box Query..'

$Profiles = $users | Select-Object SID, RoamingConfigured, Loaded, IsLocalAdmin, LocalPath, LastLogin, @{Name = "UserName"; EXPRESSION = { $_.Name } }

Write-Progress -Activity 'Jumpcloud ADMU' -Status 'Loading Jumpcloud ADMU. Please Wait.. Done!' -PercentComplete 100
Write-Log 'Loading Jumpcloud ADMU. Please Wait.. Done!'

##################
#load UI Labels

#SystemInformation
$Sync.Gui.lbComputerName.Content = $WmiComputerSystem.Name

#DomainInformation
$Sync.Gui.lbDomainName.Content = $DomainName
$Sync.Gui.lbNetBios.Content = $NetBiosName
$Sync.Gui.lbsecurechannel.Content = $securechannelstatus

#AzureADInformation
$Sync.Gui.lbAzureAD_Joined.Content = $AzureADStatus
$Sync.Gui.lbWorkplace_Joined.Content = $Workplace_join
$Sync.Gui.lbTenantName.Content = $TenantName

Function Test-Button
{
    If (![System.String]::IsNullOrEmpty($Sync.Gui.lvProfileList.SelectedItem.UserName))
    {
        If (!(Test-IsNotEmpty $Sync.Gui.tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $Sync.Gui.tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudConnectKey.Text) -and ($Sync.Gui.cb_installjcagent.IsChecked -eq $true))`
                -and ((Test-Is40chars $Sync.Gui.tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudAPIKey.Text) -and ($Sync.Gui.cb_autobindjcuser.IsChecked -eq $true))`
                -and !(Test-IsNotEmpty $Sync.Gui.tbTempPassword.Text) -and (Test-HasNoSpaces $Sync.Gui.tbTempPassword.Text)`
                -and !($Sync.Gui.$lvProfileList.selectedItem.Username -match $Sync.Gui.WmiComputerSystem.Name)`
                -and !(Test-Localusername $Sync.Gui.tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $Sync.Gui.tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $Sync.Gui.tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudConnectKey.Text) -and ($Sync.Gui.cb_installjcagent.IsChecked -eq $true) -and ($Sync.Gui.cb_autobindjcuser.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $Sync.Gui.tbTempPassword.Text) -and (Test-HasNoSpaces $Sync.Gui.tbTempPassword.Text)`
                -and !($Sync.Gui.lvProfileList.selectedItem.Username -match $Sync.Gui.WmiComputerSystem.Name)`
                -and !(Test-Localusername $Sync.Gui.tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        ElseIf (!(Test-IsNotEmpty $Sync.Gui.tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudUserName.Text) `
                -and ((Test-Is40chars $Sync.Gui.tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudAPIKey.Text) -and ($Sync.Gui.cb_autobindjcuser.IsChecked -eq $true) -and ($Sync.Gui.cb_installjcagent.IsChecked -eq $false))`
                -and !(Test-IsNotEmpty $Sync.Gui.tbTempPassword.Text) -and (Test-HasNoSpaces $Sync.Gui.tbTempPassword.Text)`
                -and !($Sync.Gui.lvProfileList.selectedItem.Username -match $Sync.Gui.WmiComputerSystem.Name)`
                -and !(Test-Localusername $Sync.Gui.tbJumpCloudUserName.Text))
        {
            $script:bDeleteProfile.Content = "Migrate Profile"
            $script:bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif(!(Test-IsNotEmpty $Sync.Gui.tbJumpCloudUserName.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudUserName.Text) `
        -and ($Sync.Gui.cb_installjcagent.IsChecked -eq $false) -and ($Sync.Gui.cb_autobindjcuser.IsChecked -eq $false)`
        -and !(Test-IsNotEmpty $Sync.Gui.tbTempPassword.Text) -and (Test-HasNoSpaces $Sync.Gui.tbTempPassword.Text)`
        -and !($Sync.Gui.lvProfileList.selectedItem.Username -match $Sync.Gui.WmiComputerSystem.Name)`
        -and !(Test-Localusername $Sync.Gui.tbJumpCloudUserName.Text))
        {
            $script:Sync.Gui.bDeleteProfile.Content = "Migrate Profile"
            $script:Sync.Gui.bDeleteProfile.IsEnabled = $true
            Return $true
        }
        Elseif(($Sync.Gui.lvProfileList.selectedItem.Username -match $Sync.Gui.WmiComputerSystem.Name) -or ($Sync.Gui.lvProfileList.selectedItem.Username -eq 'UNKNOWN ACCOUNT')){
            $script:Sync.Gui.bDeleteProfile.Content = "Select Domain Profile"
            $script:Sync.Gui.bDeleteProfile.IsEnabled = $false
            Return $false
        }
        Else
        {
            $script:Sync.Gui.bDeleteProfile.Content = "Correct Errors"
            $script:Sync.Gui.bDeleteProfile.IsEnabled = $false
            Return $false
        }
    }
    Else
    {
        $script:Sync.Gui.bDeleteProfile.Content = "Select Profile"
        $script:Sync.Gui.bDeleteProfile.IsEnabled = $false
        Return $false
    }
}

##############################
## Form changes & interactions
# Verbose checkbox
$Sync.Gui.cb_verbose.Add_Checked({$VerbosePreference = 'Continue'})

# Install JCAgent checkbox
$script:InstallJCAgent = $false
$Sync.Gui.cb_installjcagent.Add_Checked({Test-Button})
$Sync.Gui.cb_installjcagent.Add_Checked({$script:InstallJCAgent = $true})
$Sync.Gui.cb_installjcagent.Add_Checked({$Sync.Gui.tbJumpCloudConnectKey.IsEnabled =$true})
$Sync.Gui.cb_installjcagent.Add_UnChecked({Test-Button})
$Sync.Gui.cb_installjcagent.Add_Unchecked({$script:InstallJCAgent = $false})
$Sync.Gui.cb_installjcagent.Add_Unchecked({$Sync.Gui.tbJumpCloudConnectKey.IsEnabled =$false})

# Autobind JC User checkbox
$script:AutobindJCUser = $false
$Sync.Gui.cb_autobindjcuser.Add_Checked({Test-Button})
$Sync.Gui.cb_autobindjcuser.Add_Checked({$script:AutobindJCUser = $true})
$Sync.Gui.cb_autobindjcuser.Add_Checked({$Sync.Gui.tbJumpCloudAPIKey.IsEnabled =$true})
$Sync.Gui.cb_autobindjcuser.Add_UnChecked({Test-Button})
$Sync.Gui.cb_autobindjcuser.Add_Unchecked({$script:AutobindJCUser = $false})
$Sync.Gui.cb_autobindjcuser.Add_Unchecked({$Sync.Gui.tbJumpCloudAPIKey.IsEnabled =$false})

# Leave Domain checkbox
$script:LeaveDomain = $false
$Sync.Gui.cb_leavedomain.Add_Checked({$script:LeaveDomain = $true})
$Sync.Gui.cb_leavedomain.Add_Unchecked({$script:LeaveDomain = $false})

# Force Reboot checkbox
$script:ForceReboot = $false
$Sync.Gui.cb_forcereboot.Add_Checked({$script:ForceReboot = $true})
$Sync.Gui.cb_forcereboot.Add_Unchecked({$script:ForceReboot = $false})

$Sync.Gui.tbJumpCloudUserName.add_TextChanged( {
        Test-Button
        If ((Test-IsNotEmpty $Sync.Gui.tbJumpCloudUserName.Text) -or (!(Test-HasNoSpaces $Sync.Gui.tbJumpCloudUserName.Text)) -or (Test-Localusername $Sync.Gui.tbJumpCloudUserName.Text))
        {
            $Sync.Gui.tbJumpCloudUserName.Background = "#FFC6CBCF"
            $Sync.Gui.tbJumpCloudUserName.Tooltip = "Local account user name can not be empty, contain spaces or already exist on the local system."
        }
        Else
        {
            $Sync.Gui.tbJumpCloudUserName.Background = "white"
            $Sync.Gui.tbJumpCloudUserName.Tooltip = $null
            $Sync.Gui.tbJumpCloudUserName.FontWeight = "Normal"
        }
    })

$Sync.Gui.tbJumpCloudUserName.add_GotFocus( {
        $Sync.Gui.tbJumpCloudUserName.Text = ""
    })

$Sync.Gui.tbJumpCloudConnectKey.add_TextChanged( {
        Test-Button
        If (((Test-Is40chars $Sync.Gui.tbJumpCloudConnectKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudConnectKey.Text)) -eq $false)
        {
            $Sync.Gui.tbJumpCloudConnectKey.Background = "#FFC6CBCF"
            $Sync.Gui.tbJumpCloudConnectKey.Tooltip = "Connect Key Must be 40chars & Not Contain Spaces"
        }
        Else
        {
            $Sync.Gui.tbJumpCloudConnectKey.Background = "white"
            $Sync.Gui.tbJumpCloudConnectKey.Tooltip = $null
            $Sync.Gui.tbJumpCloudConnectKey.FontWeight = "Normal"
        }
    })

$Sync.Gui.tbJumpCloudAPIKey.add_TextChanged( {
    Test-Button
    If (((Test-Is40chars $Sync.Gui.tbJumpCloudAPIKey.Text) -and (Test-HasNoSpaces $Sync.Gui.tbJumpCloudAPIKey.Text)) -eq $false)
    {
        $Sync.Gui.tbJumpCloudAPIKey.Background = "#FFC6CBCF"
        $Sync.Gui.tbJumpCloudAPIKey.Tooltip = "API Key Must be 40chars & Not Contain Spaces"
    }
    Else
    {
        $Sync.Gui.tbJumpCloudAPIKey.Background = "white"
        $Sync.Gui.tbJumpCloudAPIKey.Tooltip = $null
        $Sync.Gui.tbJumpCloudAPIKey.FontWeight = "Normal"
    }
})

$Sync.Gui.tbJumpCloudConnectKey.add_GotFocus( {
    $Sync.Gui.tbJumpCloudConnectKey.Text = ""
    })

$Sync.Gui.tbJumpCloudAPIKey.add_GotFocus( {
    $Sync.Gui.tbJumpCloudAPIKey.Text = ""
})

$Sync.Gui.tbTempPassword.add_TextChanged( {
        Test-Button
        If ((!(Test-IsNotEmpty $Sync.Gui.tbTempPassword.Text) -and (Test-HasNoSpaces $Sync.Gui.tbTempPassword.Text)) -eq $false)
        {
            $Sync.Gui.tbTempPassword.Background = "#FFC6CBCF"
            $Sync.Gui.tbTempPassword.Tooltip = "Temp Password Must Not Be Empty & Not Contain Spaces"
        }
        Else
        {
            $Sync.Gui.tbTempPassword.Background = "white"
            $Sync.Gui.tbTempPassword.Tooltip = $null
            $Sync.Gui.tbTempPassword.FontWeight = "Normal"
        }
    })

# Change button when profile selected
$Sync.Gui.lvProfileList.Add_SelectionChanged( {
        $script:SelectedUserName = ($Sync.Gui.lvProfileList.SelectedItem.username)
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
        Test-Button
            try {
                $SelectedUserSID = ((New-Object System.Security.Principal.NTAccount($script:SelectedUserName)).Translate( [System.Security.Principal.SecurityIdentifier]).Value)
            }
            catch {
                $SelectedUserSID = $script:SelectedUserName
            }
        $hku = ('HKU:\'+$SelectedUserSID)
        if (Test-Path -Path $hku) {
            $script:Sync.Gui.bDeleteProfile.Content = "User Registry Loaded"
            $script:Sync.Gui.bDeleteProfile.IsEnabled = $false
            $script:Sync.Gui.tbJumpCloudUserName.IsEnabled = $false
            $script:Sync.Gui.tbTempPassword.IsEnabled = $false
        }
        else {
            $script:Sync.Gui.tbJumpCloudUserName.IsEnabled = $true
            $script:Sync.Gui.tbTempPassword.IsEnabled = $true
        }
    })

$Sync.Gui.bDeleteProfile.Add_Click( {
        # Build FormResults object
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('InstallJCAgent') -Value:($InstallJCAgent)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('AutobindJCUser') -Value:($AutobindJCUser)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('LeaveDomain') -Value:($LeaveDomain)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('ForceReboot') -Value:($ForceReboot)
        # Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName.Substring($SelectedUserName.IndexOf('\') + 1))
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('DomainUserName') -Value:($SelectedUserName)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudUserName') -Value:($tbJumpCloudUserName.Text)
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('TempPassword') -Value:($tbTempPassword.Text)
        if(($tbJumpCloudConnectKey.Text).length -eq 40){
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudConnectKey') -Value:($tbJumpCloudConnectKey.Text)
        }
        if(($tbJumpCloudAPIKey.Text).length -eq 40){
            Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('JumpCloudAPIKey') -Value:($tbJumpCloudAPIKey.Text)
        }
        Add-Member -InputObject:($FormResults) -MemberType:('NoteProperty') -Name:('NetBiosName') -Value:($SelectedUserName)
        # Close form
        $Sync.Window.Close()
    })
########################
# JCConsole Link
$Sync.Gui.tbjcconsole.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://console.jumpcloud.com/login') })

# JCADMUGH Link
$Sync.Gui.tbjcadmugh.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://github.com/TheJumpCloud/jumpcloud-ADMU') })

# JCSupport Link
$Sync.Gui.tbjcsupport.Add_PreviewMouseDown( { [System.Diagnostics.Process]::start('https://support.jumpcloud.com/support/s/') })

# jcadmulog
$Sync.Gui.tbjcadmulog.Add_PreviewMouseDown( { Invoke-Item "C:\Windows\Temp\JCADMU.log" })

# close button
$Sync.Gui.btn_close.Add_Click( {
    $Sync.Window.Close()
})

# move window
$Sync.Window.Add_MouseLeftButtonDown({
    $Sync.Window.DragMove()
})

# Put the list of profiles in the profile box
$Profiles | ForEach-Object { $Sync.Gui.lvProfileList.Items.Add($_) | Out-Null }

# display the GUI
$Sync.Window.ShowDialog() | Out-Null
If ($Sync.Gui.bDeleteProfile.IsEnabled -eq $true)
{
    Return $FormResults
}