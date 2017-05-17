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

function Send-PhishingEmail {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$EmailAddress
    )
    process {
        $Parameters = @{
            To = $EmailAddress
            From = "SecurityAdministrator@tervistumbler.cc"
            Subject = "Microsoft Office 365 Security Setting Change, email validation required"
            Body = @"
<html><head>
<meta http-equiv="Content-Type" content="text/html; charset=us-ascii"><meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
<!-- W15P2 TwoColumn RTL -->
<style>
    table td {border-collapse:collapse;margin:0;padding:0;}
 p.MsoNormal
	{margin-bottom:.0001pt;
	font-size:11.0pt;
	font-family:"Calibri","sans-serif";
	    width: 576px;
        margin-left: 0in;
        margin-right: 0in;
        margin-top: 0in;
    }
</style>

<!--  -->

<!--  -->

</head><body>


<table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-right: 0px">
    <tr>
        <td valign="top">

<!-- -->

<table width="580" cellpadding="0" cellspacing="0" border="0">
    <tr>
        <td width="20" bgcolor="#00188f">&nbsp;</td>
        <td width="270" align="left" valign="bottom" bgcolor="#00188f" style="color:#fff; font-size:10px; font-family:Arial; padding:22px 0;"><img src="http://image.email.microsoftonline.com/lib/fe95157074600c7e7c/m/1/33337_W15P2_Office365.png" width="140" height="31" alt="Office 365" border="0"> </td>
        <td width="20" bgcolor="#00188f">&nbsp;</td>
    </tr>
    </table>
<table cellpadding="0" cellspacing="0" border="0">
	<tr>
		<td align="left" style="color:#3d3d3d; font-family:'Segoe UI',Arial,sans-serif; font-size:13px; line-height:16px; padding:20px 0 0;">
<p class="MsoNormal">
Dear customer,<br>
<br>
<p class="MsoNormal">Your Microsoft Office 365 Security Administrator has made a change to your security settings.</p>
<br>
<p class="MsoNormal">Please validate your email address by clicking the link below to avoid your email address being suspended.</p>
<br>

<p class="MsoNormal"><a href="http://microsoft.tervistumbler.cc/security/validation/$([Uri]::EscapeDataString($EmailAddress))" target="_blank">Validate Email Address</a> </p>
<o:p></o:p>
</p>
<p class="MsoNormal">
                <o:p>&nbsp;</o:p></p>
            <p class="MsoNormal">
                Thank you,<o:p></o:p></p>
            <p class="MsoNormal">
                Microsoft Office 365 Reporting<o:p></o:p></p>
&nbsp;</td>
	</tr>
</table>
        </td>
    </tr>
</table>
<table width="580" cellpadding="0" cellspacing="0" border="0">
    <tr>
        <td width="20" bgcolor="#00188f">&nbsp;</td>
        <td width="270" colspan="2" align="left" valign="middle" bgcolor="#00188f" style="color:#fff; font-family:'Segoe UI',Arial,sans-serif; font-size:10px; line-height:16px; padding:10px 0;">
            <table cellpadding="0" cellspacing="0" border="0">
    <tr>
        <td style="color:#fff; font-family:'Segoe UI',Arial,sans-serif; font-size:10px; line-height:16px; padding-bottom:4px;">
            This message was sent from an unmonitored email address.<br> Please do not reply to this message. <a href="http://www.microsoft.com/online/legal/v2/?docid=18&amp;langid=en-US" title="Privacy" style="color:#eb3c00;">Privacy</a> | <a href="http://www.microsoft.com/online/legal/v2/?docid=13&amp;langid=en-US" title="Legal" style="color:#eb3c00;">Legal</a>
        </td>
    </tr>
    <tr>
        <td style="color:#fff; font-family:'Segoe UI',Arial,sans-serif; font-size:10px; line-height:16px;">
            Microsoft Corporation | One Microsoft Way,<br>Redmond, WA 98052-6399
        </td>
    </tr>
</table>
        </td>
        <td width="270" align="right" valign="middle" bgcolor="#00188f" style="padding:20px 0;"><img src="http://image.email.microsoftonline.com/lib/fe95157074600c7e7c/m/1/33337_W15P2_Logo_Microsoft.png" width="68" height="15" alt="Microsoft" border="0"></td>
        <td width="20" bgcolor="#00188f">&nbsp;</td>
    </tr>
</table>
<!--  -->

        </td>
        <td valign="top" width="50%"></td>
    </tr>
</table>
</body></html>
"@
        }
        Send-MailMessage -SmtpServer cudaspam.tervis.com -BodyAsHtml @Parameters
    }
}