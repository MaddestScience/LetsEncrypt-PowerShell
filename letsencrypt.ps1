## Variable settings from Management Panel
param(
[string]
$option,
$domain
)
# IMPORT MODULE ACMESharp
Import-Module ACMESharp
## Warning preferences
$WarningPreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'


## Static variables
$date = Get-Date -format "yyyyMMdd"
$domainfiles = Get-ChildItem "C:\Central_SSLStore\domains\" -Filter *.txt
#$option = "Verify"


Function Verify(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "$domain-$date"
        Write-Host "$domain"
        Write-Host "$domainalias"

        Write-Host "-------------------------------------"
        Write-Host ""
        Write-Host "Adding new ACMEIdentifier for $domain."
        $GETID2 = Get-ACMEIdentifier $domain -ErrorAction SilentlyContinue
        if ($GETID2.Identifier -eq $domain){ 
            Write-Host "ID Already Exists"
        } else {
            New-ACMEIdentifier -Dns $domain -Alias $domainalias
        }
        Write-Host ""
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Getting verification information for $domain."
        $compACMEChall = Complete-ACMEChallenge $domainalias -ChallengeType dns-01 -Handler manual
        $dnsRRName = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordName
        $dnsRRValue = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordValue
        Write-Host ""
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "You can validate the domain $domain"
        Write-Host "With TXT DNS Record: $dnsRRName"
        write-host "And Value: $dnsRRValue"
        Write-Host ""
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Adding Record to the DNS Server..."
        dnscmd /RecordDelete $domain _acme-challenge TXT /f
        dnscmd /RecordAdd $domain _acme-challenge 1 TXT "$dnsRRValue"

        Write-Host ""
        $subdomains = Get-Content $domainname.FullName
        Foreach ($subdomain in $subdomains) {
            $fqdn = "$subdomain.$domain"
            $subdomainalias = "$fqdn-$date"

            Write-Host ""
            Write-Host "---------------------------------------"
            Write-Host ""
            Write-Host "Adding new ACMEIdentifier for:"
            Write-Host " - $fqdn"
            Write-Host ""
            New-ACMEIdentifier -DNS "$fqdn" -Alias "$subdomainalias"
            $compACMEChall = Complete-ACMEChallenge "$subdomainalias" -ChallengeType dns-01 -Handler manual
            $dnsRRName = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordName
            $dnsRRValue = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordValue
            Write-Host " Adding DNS for $fqdn"
            dnscmd /RecordDelete $domain _acme-challenge.$subdomain TXT /f
            dnscmd /RecordAdd $domain _acme-challenge.$subdomain 1 TXT "$dnsRRValue"

            Write-Host ""
            Write-Host "---------------------------------------"
        }
    }
}


Function Status(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "$domain-$date"
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Check ACME Status for $domain"
        $Cert = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
        $CertStatus = $Cert.Status
        $CertHN = $Cert.HandlerName
        $Certy = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01)
        Write-Host ""
        Write-Host "Idenitifier:" $Certy.Identifier
        Write-Host "Status:" $Certy.Status
    
        Write-Host ""
        Write-Host "Certificate Handler Name: $CertHN"
        Write-Host ""

        $subdomains = Get-Content $domainname.FullName
        Foreach ($subdomain in $subdomains) {
            $fqdn = "$subdomain.$domain"
            $subdomainalias = "$fqdn-$date"
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "Check ACME Status for $fqdn"
            $Cert = (Update-ACMEIdentifier $subdomainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
            $CertStatus = $Cert.Status
            $CertHN = $Cert.HandlerName
            $Certy = (Update-ACMEIdentifier $subdomainalias -ChallengeType dns-01)
            Write-Host ""
            Write-Host "Idenitifier:" $Certy.Identifier
            Write-Host "Status:" $Certy.Status
        
            Write-Host ""
            Write-Host "Certificate Handler Name: $CertHN"
            Write-Host ""
        }
    }
}

Function SubmitChallenge() {
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "$domain-$date"
        ## Submitting challenge for main domain
        Write-Host "Submitting Challenge for $domainalias"
        Submit-ACMEChallenge $domainalias -ChallengeType dns-01

        ## Submitting the challenge for all subdomains
        $subdomains = Get-Content $domainname.FullName
        Foreach ($subdomain in $subdomains) {
            $fqdn = "$subdomain.$domain"
            $subdomainalias = "$fqdn-$date"
            Write-Host "Submitting Challenge for $subdomainalias"
            Submit-ACMEChallenge $subdomainalias -ChallengeType dns-01
        }
    }
}


Function GetCert(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "$domain-$date"
        $subdomains = Get-Content $domainname.FullName
        $subdomainaliasses = @()
        Foreach ($subdomain in $subdomains) {
            $subdomainaliasses += "$subdomain.$domain-$date"
        }
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Check ACME Status"
        $Cert = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
        $CertStatus = $Cert.Status
        Write-Host ""
        Write-Host "Certificate Status: $CertStatus"
        Write-Host ""
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Generating Certificate for $domain..."
        Write-Host ""
        New-ACMECertificate $domain -Generate -AlternativeIdentifierRefs $subdomainaliasses -Alias $domainalias
        Write-Host "Submitting Certificate for $domain..."
        Submit-ACMECertificate $domainalias
        Write-Host ""
        Write-Host "Saving Certificate for '$domain' in the 'Central SSL Store'..."
        Get-ACMECertificate $domainalias -ExportKeyPEM "C:\Central_SSLStore\$domain.key.pem"
        Get-ACMECertificate $domainalias -ExportCsrPEM "C:\Central_SSLStore\$domain.csr.pem"
        Get-ACMECertificate $domainalias -ExportPkcs12 "C:\Central_SSLStore\$domain.pfx"
        Get-ACMECertificate $domainalias -ExportCertificatePEM "C:\Central_SSLStore\$domain.crt.pem" -ExportCertificateDER "C:\Central_SSLStore\$domain.crt"
        Get-ACMECertificate $domainalias -ExportIssuerPEM "C:\Central_SSLStore\$domain-issuer.crt.pem" -ExportIssuerDER "C:\Central_SSLStore\$domain-issuer.crt"
        Write-Host ""
        Write-Host "---------------------------------------------------"
    }
}

if($option -eq "Verify") {
    Verify 
}
if($option -eq "Status") {
    Status
}
if($option -eq "GetCert") {
    GetCert
}
if ($option -eq "SubmitChallenge"){
    SubmitChallenge
}