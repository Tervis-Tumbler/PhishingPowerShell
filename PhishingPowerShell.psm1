function Invoke-PhisingWebsiteProvision {
    param (
        $EnvironmentName
    )
    Invoke-ClusterApplicationProvision -ClusterApplicationName Phishing -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisClusterApplicationNode -ClusterApplicationName KafkaBroker -EnvironmentName $EnvironmentName
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