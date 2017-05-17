function Invoke-PhisingWebsiteProvision {
    param (
        $EnvironmentName
    )
    Invoke-ClusterApplicationProvision -ClusterApplicationName Phishing -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisClusterApplicationNode -ClusterApplicationName Phishing -EnvironmentName $EnvironmentName
    $Nodes | New-PhishingSiteFirewallRules
    $Nodes | Install-PhishingWebsiteService
    $Nodes | Start-ServiceOnNode -Name PhishingWebsite
}

function New-PhishingSiteFirewallRules {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $FirewallRule = Get-NetFirewallRule -Name "PhishingSiteFirewallRules" -ErrorAction SilentlyContinue
            if (-not $FirewallRule) {
                New-NetFirewallRule -Name "PhishingSiteFirewallRules" -DisplayName "PhishingSiteFirewallRules" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow -Group PhishingSiteFirewallRules | Out-Null
            }
        }
    }
}

function Get-EmailAddressesToPhish {
    $Mailbox = Get-O365Mailbox |
    Add-Member -MemberType ScriptProperty -Name EmailAddressObjects -Value {
        foreach ($EmailAddress in $this.EmailAddresses) {
            $EmailAddressObjectParts = $EmailAddress -split ":"
            [PSCustomObject]@{
                Type = $EmailAddressObjectParts[0]
                Address = $EmailAddressObjectParts[1]
            }
        }
    } -PassThru

    $SMTPAddresses = $Mailbox.EmailAddressObjects | 
    where type -EQ smtp |
    where Address -Match "Tervis.com"
}

function Get-PhishingWebsiteRoot {
    "c:\ProgramData\Tervis\netcoreapp1.1\publish"
}

function Start-PhishingWebsiteProcess {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $WebsiteDirectory = Get-PhishingWebsiteRoot
    }
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            #Set-Location -Path $Using:WebsiteDirectory
            #Start-Process dotnet $Using:WebsiteDirectory\asp.netcore.dll
        }
    }
}

function Install-PhishingWebsiteService {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $WebsiteDirectory = Get-PhishingWebsiteRoot
    }
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            nssm install PhishingWebsite dotnet "$Using:WebsiteDirectory\asp.netcore.dll"
            nssm set PhishingWebsite AppDirectory $Using:WebsiteDirectory
        }
    }
}

function Remove-PhishingWebsiteService {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $WebsiteDirectory = Get-PhishingWebsiteRoot
    }
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Stop-Service PhishingWebsite -Force
            sc.exe delete PhishingWebsite
        }
    }
}

function Get-PhishingWebsiteService {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Get-Service -ComputerName $ComputerName phishingwebsite
    }
}

function Get-PhishingWebsiteProcess {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Get-Process -ComputerName $ComputerName | 
        where name -Match dotnet
    }
}

function Stop-PhishingWebsiteProcess {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-Process -ComputerName $ComputerName | 
            where name -Match dotnet |
            Stop-Process
        }
    }
}

function Get-PhishingWebsiteHarvestedEmails {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $WebsiteDirectory = Get-PhishingWebsiteRoot
    }
    process {
        $LogDirectoryRemote = "$WebsiteDirectory\logs" | ConvertTo-RemotePath -ComputerName $ComputerName
        $LogFiles = Get-ChildItem -Path $LogDirectoryRemote -File        
        $LogFiles | 
        Get-Content | 
        where {$_ -match "request"} | 
        where {$_ -match "security/validation"} |
        Select-StringBetween -After "security/validation/" -Before "  "
    }
}

function Invoke-PhishingWebsiteLogRollover {
    param (
        [Parameter(ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $WebsiteDirectory = Get-PhishingWebsiteRoot
    }
    process {
        Stop-ServiceOnNode -ComputerName $ComputerName -Name PhishingWebsite
        $LogDirectoryRemote = "$WebsiteDirectory\logs" | ConvertTo-RemotePath -ComputerName $ComputerName
        $LogFiles = Get-ChildItem -Path $LogDirectoryRemote -File
        $ArchiveDirectory = New-Item -ItemType Directory -Path $LogDirectoryRemote -Name $(Get-Date -Format -- FileDateTime)
        $LogFiles | Move-Item -Destination $ArchiveDirectory
        Start-ServiceOnNode -ComputerName $ComputerName -Name PhishingWebsite
    } 
}