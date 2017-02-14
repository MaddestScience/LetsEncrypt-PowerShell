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
$certpath = "D:\Path\to\save\certificates\of\LetsEncrypt\"
$domainfiles = Get-ChildItem "C:\Path\to\the\domain\txt\files\" -Filter *.txt

# $option = "Verify"
# $option = "Status"
# $option = "SubmitChallenge"
# $option = "GetCert"

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
        Write-Host "Status:" $CertStatus
        Write-Host "Certificate Handler Name: $CertHN"
        Update-ACMEIdentifier $domainalias
        Write-Host ""
        Write-Host "---------------------------------------------------"
        


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
            Write-Host "Status:" $CertStatus
            Write-Host "Certificate Handler Name: $CertHN"
            Update-ACMEIdentifier $subdomainalias
            Write-Host ""
            Write-Host "---------------------------------------------------"
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
        Update-ACMEIdentifier $domainalias
        ## Submitting the challenge for all subdomains
        $subdomains = Get-Content $domainname.FullName
        Foreach ($subdomain in $subdomains) {
            $fqdn = "$subdomain.$domain"
            $subdomainalias = "$fqdn-$date"
            Write-Host "Submitting Challenge for $subdomainalias"
            Submit-ACMEChallenge $subdomainalias -ChallengeType dns-01
            Update-ACMEIdentifier $subdomainalias
        }
    }
}

Function GrabCerts($domain){ 
    $domainalias = "$domain-$date"
    Write-Host ""
    Write-Host "Saving Certificate for '$domain' in the 'Central SSL Store'..."
    If(!(test-path $certpath\$domain)) {
        New-Item -ItemType Directory -Force -Path $certpath\$domain
    }
    Get-ACMECertificate $domainalias -ExportKeyPEM "$certpath\$domain\$domain.key.pem"
    Get-ACMECertificate $domainalias -ExportCsrPEM "$certpath\$domain\$domain.csr.pem"
    Get-ACMECertificate $domainalias -ExportPkcs12 "$certpath\$domain\$domain.pfx"
    Get-ACMECertificate $domainalias -ExportCertificatePEM "$certpath\$domain\$domain.crt.pem" -ExportCertificateDER "$certpath\$domain\$domain.crt"
    Get-ACMECertificate $domainalias -ExportIssuerPEM "$certpath\$domain\$domain-issuer.crt.pem" -ExportIssuerDER "$certpath\$domain\$domain-issuer.crt"
}
Function ValidIssuer($domain) {
    $domainalias = "$domain-$date"
    $ValidIssuer = (Update-ACMECertificate $domainalias).IssuerSerialNumber
    if ($ValidIssuer -eq '') {
        ValidIssuer -domain $domain
    } else {
        Write-Host "IssuerSerialNumber: $ValidIssuer" 
        GrabCerts -domain $domain
    }
}


Function GetCert(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "$domain-$date"
        $subdomains = Get-Content $domainname.FullName
        $sd_count = $subdomains.Count
        $subcount = 0
        Write-Host "Domainname: $domain"
        Write-Host "Domain alias: $domainalias" 
        $subdomainaliasses = @()
        Foreach ($subdomain in $subdomains) {
        Write-Host "Subdomain: $subdomain"
            $fqdn = "$subdomain.$domain"
            Write-Host "FQDN: $fqdn" 
            $subcount += 1
            if ($subcount -eq $sd_count) {
                $subdomainaliasses += "$fqdn-$date"
            } else {
                $subdomainaliasses += "$fqdn-$date"
            }
        }

        # $subdomainaliasses = $subdomainaliasses | out-string
        Write-Host "Subdomain Aliasses:"
        Write-Host "$subdomainaliasses"
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Check ACME Status"
        $Cert = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
        $CertStatus = $Cert.Status
        Write-Host "Identifier Status: $CertStatus"
        Write-Host ""
        Write-Host "---------------------------------------------------"
        Write-Host ""
        Write-Host "Generating Certificate for $domain..."
        Write-Host ""
        New-ACMECertificate $domainalias -Generate -AlternativeIdentifierRefs @($subdomainaliasses) -Alias $domainalias
        Write-Host "        New-ACMECertificate $domainalias -Generate -AlternativeIdentifierRefs @($subdomainaliasses) -Alias $domainalias"
        Write-Host "Submitting Certificate for $domain..."
        Submit-ACMECertificate $domainalias
        $ValidIssuer = (Update-ACMECertificate $domainalias).IssuerSerialNumber
        if ($ValidIssuer -eq '') {
            ValidIssuer -domain $domain
        }else{
            Write-Host "IssuerSerialNumber: $ValidIssuer" 
            GrabCerts -domain $domain
        }
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