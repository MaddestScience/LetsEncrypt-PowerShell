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
$date = Get-Date -format "yyyyMM"
$certdate = Get-Date -format "yyyyMMddHHmmss"
$certpath = "D:\Websites\icttw\TW000\ictteamwork.nl\LetsEncrypt\"
$EventLogPath = "D:\Websites\icttw\TW000\ictteamwork.nl\LetsEncrypt\logs\"
$domainfiles = Get-ChildItem "D:\Websites\icttw\TW000\ictteamwork.nl\LetsEncrypt\domains" -Filter *.txt

$certpass = '@St0MP4$$W0rD4pFx!'
# $certpass = 'aircontrolenterprise'
$crt = $false

# $option = "Verify"
# $option = "SubmitChallenge"
# $option = "Status"
# $option = "GetCert"
# $option = "GrabCerts"
# $option = "RemoveTXT"

#Function Write and Manage Log
function WriteFileEventLog($EventCat, $EventType, $EventTask, $EventMessage, $EventBreak) {
    #CycleLog

    $EventLogFile = "MKCert-$date.Log"
    $oldTime = [int]60
    foreach ($l in Get-ChildItem $EventLogPath) { 
        Get-ChildItem $EventLogPath -Recurse -Include "MKCert-*.*" | WHERE {$_.CreationTime -le $(Get-Date).AddDays(-$oldTime)} | Remove-Item -Force 
    } 
    #Complete Log File with Log path
    $LogFile = "$EventLogPath" + "\" + "$EventLogFile"
    $EventDate = Get-Date  

    #Setup log Entry
    if($EventBreak -eq "True") {
         if ($domain[0..0] -eq '#') {
            $EventLog = "$EventDate - $domain - ==================    SINGLE DOMAIN CERT   ===================="
         } else {
            $EventLog = "$EventDate - $domain - ==============================================================="
         }
    } else {   
        $EventLog = "$EventDate - $domain - $EventCat - $EventType - $EventMessage"               
    }
    #Add log entry
    Add-Content $LogFile $EventLog
}

function RemoveTXT {
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "a-$domain-$date"
        dnscmd /RecordDelete $domain _acme-challenge TXT /f
        $subdomains = Get-Content $domainname.FullName
        Foreach ($subdomain in $subdomains) {
            $fqdn = "$subdomain.$domain"
            $subdomainalias = "a-$fqdn-$date"
            dnscmd /RecordDelete $domain _acme-challenge.$subdomain TXT /f
        }
    }
}

Function Verify(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "a-$domain-$date"
        if ($domain[0..0] -eq '#') {
            $domain = $domain.substring(1,($domain | measure-object -character | select -expandproperty characters) - 1)
            $domainname = $domain.Split(".")[(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) -2)..($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words)] -join "."
            $subdomain = $domain.Split(".")[0..(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) - 3)] -join "."
            $fqdn = "$subdomain.$domainname"
            $domainalias = "a-$fqdn-$date"
            Write-Host "Domain: $domainname"
            Write-Host "Subdomain: $subdomain"
            Write-Host "fqdn: $fqdn"
            Write-Host "domainalias: $domainalias"
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Starting the verification of $fqdn."
            Write-Host "==============================================================="
            Write-Host ""
            $found = $false
            Try {
                Get-ACMEIdentifier $domainalias -ErrorAction Stop
                Write-Host "Found an existing ACMEIdentifier for $fqdn."
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Found an existing ACMEIdentifier for $fqdn."
			    $valid = $false
			    $valid = (Get-ACMEIdentifier $domainalias -ErrorAction SilentlyContinue).Status
			    if ($valid -eq 'valid') { 
    				WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "The found ACMEIdentifier has already been validated, skipping validation."
				    Write-Host "The found ACMEIdentifier has already been validated, skipping validation."
	                $found = $true
			    }
            } 
            Catch {
                Write-Host "An Identifier for $fqdn did not exist."
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "An ACMEIdentifier for $fqdn did not exist."
            }
            if(!$found) {
    			Try {
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Making a new ACMEIdentifier for $fqdn."
				    Write-Host "Adding new ACMEIdentifier for $fqdn."
				    New-ACMEIdentifier -Dns $fqdn -Alias $domainalias -ErrorAction stop
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Made a new ACMEIdentifier for $fqdn."
			    } Catch {
    				Write-Host "Failed while making a new ACMEIdentifier for $fqdn."
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Failed while making a new ACMEIdentifier for $fqdn."
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Error message: $($_.Exception.Message)" 
			    }
            }
            Write-Host ""
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "Getting verification information for $fqdn."
            $compACMEChall = Complete-ACMEChallenge $domainalias -ChallengeType dns-01 -Handler manual
            $dnsRRName = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordName
            $dnsRRValue = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordValue
            Write-Host ""
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "You can validate the domain $fqdn"
            Write-Host "With TXT DNS Record: $dnsRRName"
            write-host "And Value: $dnsRRValue"
            Write-Host ""
            Write-Host "---------------------------------------------------"
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Adding DNS TXT Record for $fqdn."
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "DNS Record: $dnsRRName"
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Validation Key: $dnsRRValue"
            Write-Host ""
            Write-Host "Adding Record to the DNS Server..."
            dnscmd /RecordDelete $domainname _acme-challenge.$subdomain TXT /f
            dnscmd /RecordAdd $domainname _acme-challenge.$subdomain 1 TXT "$dnsRRValue"
            Write-Host ""
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
        } else {
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Starting the verification of $domain."
    
            Write-Host "==============================================================="
            Write-Host ""
            $found = $false
            Try {
                Get-ACMEIdentifier $domainalias -ErrorAction Stop
                Write-Host "Found an existing ACMEIdentifier for $domain."
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Found an existing ACMEIdentifier for $domain."
			    $valid = $false
			    $valid = (Get-ACMEIdentifier $domainalias -ErrorAction Stop).Status
			    if ($valid -eq 'valid') { 
    				WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "The found ACMEIdentifier has already been validated, skipping validation."
				    Write-Host "The found ACMEIdentifier has already been validated, skipping validation."
	                $found = $true
			    }
            } 
            Catch {
                Write-Host "An Identifier for $domain did not exist."
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "An ACMEIdentifier for $domain did not exist."
            }
            if(!$found) {
    			Try {
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Making a new ACMEIdentifier for $domain."
				    Write-Host "Adding new ACMEIdentifier for $domain."
				    New-ACMEIdentifier -Dns $domain -Alias $domainalias -ErrorAction stop
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Made a new ACMEIdentifier for $domain."
			    } Catch {
    				Write-Host "Failed while making a new ACMEIdentifier for $domain."
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Failed while making a new ACMEIdentifier for $domain."
				    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Error message: $($_.Exception.Message)" 
			    }
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
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Adding DNS TXT Record for $domain."
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "DNS Record: $dnsRRName"
            WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Validation Key: $dnsRRValue"
            Write-Host ""
            Write-Host "Adding Record to the DNS Server..."
            dnscmd /RecordDelete $domain _acme-challenge TXT /f
            dnscmd /RecordAdd $domain _acme-challenge 1 TXT "$dnsRRValue"
            Write-Host ""
            $subdomains = Get-Content $domainname.FullName
            Foreach ($subdomain in $subdomains) {
                WriteFileEventLog -EventBreak "True"
                $fqdn = "$subdomain.$domain"
                $subdomainalias = "a-$fqdn-$date"
    
                Write-Host ""
                Write-Host "---------------------------------------"
                Write-Host ""
                Write-Host "Adding new ACMEIdentifier for:"
                Write-Host " - $fqdn"
                Write-Host ""
                $found = $false
                Try {
                    Get-ACMEIdentifier $subdomainalias -ErrorAction Stop
                    Write-Host "Found an existing ACMEIdentifier for $fqdn."
                    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Found an existing ACMEIdentifier for $fqdn."
				    $valid = $false
				    $valid = (Get-ACMEIdentifier $subdomainalias -ErrorAction Stop).Status
				    if ($valid -eq 'valid') { 
    					WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "The found ACMEIdentifier has already been validated, skipping validation."
					    Write-Host "The found ACMEIdentifier has already been validated, skipping validation."
					    $found = $true
				    }
                    $found = $true
                }
                Catch {
                    Write-Host "An Identifier for $fqdn did not exist."
                    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "An ACMEIdentifier for $fqdn did not exist."
                }
                if(!$found) {
    				Try {
					    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Making a new ACMEIdentifier for $fqdn."
					    Write-Host "Adding new ACMEIdentifier for $fqdn."
					    New-ACMEIdentifier -Dns $fqdn -Alias $subdomainalias -ErrorAction stop
					    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Made a new ACMEIdentifier for $fqdn."
				    } Catch {
    					Write-Host "Failed while making a new ACMEIdentifier for $fqdn."
					    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Failed while making a new ACMEIdentifier for $fqdn."
					    WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Error" -EventMessage "Error message: $($_.Exception.Message)" 
				    }
                }
                $compACMEChall = Complete-ACMEChallenge "$subdomainalias" -ChallengeType dns-01 -Handler manual
                $dnsRRName = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordName
                $dnsRRValue = ($compACMEChall.Challenges | Where-Object {$_.Type -eq "dns-01"}).Challenge.RecordValue
                Write-Host " Adding DNS for $fqdn"
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Adding DNS TXT Record for $fqdn."
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "DNS Record: $dnsRRName"
                WriteFileEventLog  -EventCat "Certificate Verification" -EventType "Information" -EventMessage "Validation Key: $dnsRRValue"
                dnscmd /RecordDelete $domain _acme-challenge.$subdomain TXT /f
                dnscmd /RecordAdd $domain _acme-challenge.$subdomain 1 TXT "$dnsRRValue"
    
                Write-Host ""
                Write-Host "---------------------------------------"
            }
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
        }
    }
}


Function Status(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "a-$domain-$date"
        if ($domain[0..0] -eq '#') {
            $domain = $domain.substring(1,($domain | measure-object -character | select -expandproperty characters) - 1)
            $domainname = $domain.Split(".")[(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) -2)..($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words)] -join "."
            $subdomain = $domain.Split(".")[0..(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) - 3)] -join "."
            $fqdn = "$subdomain.$domainname"
            $domainalias = "a-$fqdn-$date"
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "Check ACME Status for $fqdn"
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
        } else {
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
                $subdomainalias = "a-$fqdn-$date"
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
}

Function SubmitChallenge() {
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "a-$domain-$date"
        if ($domain[0..0] -eq '#') {
            $domain = $domain.substring(1,($domain | measure-object -character | select -expandproperty characters) - 1)
            $domainname = $domain.Split(".")[(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) -2)..($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words)] -join "."
            $subdomain = $domain.Split(".")[0..(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) - 3)] -join "."
            $fqdn = "$subdomain.$domainname"
            $domainalias = "a-$fqdn-$date"
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            ## Submitting challenge for main domain
            Try {
                Write-Host "Submitting Challenge for $fqdn."
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitting Challenge for $fqdn."
                Submit-ACMEChallenge $domainalias -ChallengeType dns-01 -ErrorAction Stop
                Write-Host "Submitted Challenge for $fqdn."
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitted Challenge for $fqdn."
            }
            Catch {
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Error" -EventMessage "Failed submitting challenge: $($_.Exception.Message)"
                Write-Host "Failed submitting challenge for $fqdn."
            }
            Update-ACMEIdentifier $domainalias
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
        } else {
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            ## Submitting challenge for main domain
            Try {
                Write-Host "Submitting Challenge for $domain."
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitting Challenge for $domain."
                Submit-ACMEChallenge $domainalias -ChallengeType dns-01 -ErrorAction Stop
                Write-Host "Submitted Challenge for $domain."
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitted Challenge for $domain."
            }
            Catch {
                WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Error" -EventMessage "Failed submitting challenge: $($_.Exception.Message)"
                Write-Host "Failed submitting challenge for $domain."
            }
            Update-ACMEIdentifier $domainalias
            ## Submitting the challenge for all subdomains
            $subdomains = Get-Content $domainname.FullName
            Foreach ($subdomain in $subdomains) {
                $fqdn = "$subdomain.$domain"
                $subdomainalias = "a-$fqdn-$date"
                WriteFileEventLog -EventBreak "True"
                Try {
                    Write-Host "Submitting Challenge for $fqdn"
                    WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitting Challenge for $fqdn"
                    Submit-ACMEChallenge $subdomainalias -ChallengeType dns-01 -ErrorAction Stop
                    Write-Host "Submitted Challenge for $fqdn."
                    WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Information" -EventMessage "Submitted Challenge for $fqdn."
                }
                Catch {
                    WriteFileEventLog  -EventCat "Certificate Challenge" -EventType "Error" -EventMessage "Failed submitting challenge: $($_.Exception.Message)"
                    Write-Host "Failed submitting challenge for $fqdn."
                }
                Update-ACMEIdentifier $subdomainalias
            }
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
        }
    }
}

Function GrabCerts($domain){ 
    $domainalias = "a-$domain-$date"
    $certalias = "a-$domain-$certdate"
    Write-Host ""
    Try {
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Information" -EventMessage "Moving old certificate for $domain."
        Move-Item "$certpath\certificates\$domain.pfx" ("$certpath\oldcerts\$domain.{0:yyyyMMddhhmm}.pfx" -f (get-date)) -ErrorAction Stop
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Information" -EventMessage "Moved old certificate for $domain."
    }
    Catch {
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Error" -EventMessage "Moving old certificate for $domain failed: $($_.Exception.Message)"
    }
    if ($crt) {
        Get-ACMECertificate $certalias -ExportKeyPEM "$certpath\certificates\crt\$domain.key.pem"
        Get-ACMECertificate $certalias -ExportCsrPEM "$certpath\certificates\crt\$domain.csr.pem"
        Get-ACMECertificate $certalias -ExportCertificatePEM "$certpath\certificates\crt\$domain.crt.pem" -ExportCertificateDER "$certpath\certificates\$domain.crt"
        Get-ACMECertificate $certalias -ExportIssuerPEM "$certpath\certificates\crt\$domain-issuer.crt.pem" -ExportIssuerDER "$certpath\certificates\$domain-issuer.crt"
    }
    Try {
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Information" -EventMessage "Downloading Certificate for $domain."
        Write-Host "Downloading Certificate for $domain."
        Get-ACMECertificate $certalias -ExportPkcs12 "$certpath\certificates\$domain.pfx" -CertificatePassword $certpass -ErrorAction Stop
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Information" -EventMessage "Downloaded Certificate for $domain Succesfully."
        Write-Host "Downloaded Certificate for $domain Succesfully."
    }
    Catch {
        WriteFileEventLog  -EventCat "Certificate Grab" -EventType "Error" -EventMessage "Download Certificate for $domain Failed: $($_.Exception.Message)"
        Write-Host "Download Certificate for $domain Failed: $($_.Exception.Message)"
    }
}

Function ValidIssuer($domain) {
    $domainalias = "a-$domain-$date"
    $certalias = "a-$domain-$certdate"
    $ValidIssuer = (Update-ACMECertificate $certalias).IssuerSerialNumber
    if ($ValidIssuer -eq '') {
        WriteFileEventLog  -EventCat "Certificate Check" -EventType "Information" -EventMessage "Issuer Validation failed for $domain, trying again."
        ValidIssuer -domain $domain
    } else {
        WriteFileEventLog  -EventCat "Certificate Check" -EventType "Information" -EventMessage "Issuer Validation succeeded, Issuer Serial Number: $ValidIssuer"
        Write-Host "IssuerSerialNumber: $ValidIssuer" 
        GrabCerts -domain $domain
    }
}


Function GetCert(){ 
    Foreach ($domainname in $domainfiles) {
        $domain = $domainname.BaseName
        $domainalias = "a-$domain-$date"
        $certalias = "a-$domain-$certdate"
        if ($domain[0..0] -eq '#') {
            $domain = $domain.substring(1,($domain | measure-object -character | select -expandproperty characters) - 1)
            $domainname = $domain.Split(".")[(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) -2)..($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words)] -join "."
            $subdomain = $domain.Split(".")[0..(($domain.Split(".") | Measure-Object -Word | Select -ExpandProperty words) - 3)] -join "."
            $fqdn = "$subdomain.$domainname"
            $domainalias = "a-$fqdn-$date"
            $certalias = "a-$domain-$certdate"
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "Check ACME Status"
            $Cert = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
            $CertStatus = $Cert.Status
            Write-Host "Identifier Status: $CertStatus"
            Write-Host ""
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Try {
                Write-Host "Generating Certificate for $fqdn..."
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Information" -EventMessage "Generating Certificate for $fqdn..."
                New-ACMECertificate $domainalias -Generate -Alias $certalias -ErrorAction Stop
                Write-Host "Generated Certificate for $fqdn..."
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Information" -EventMessage "Generated Certificate for $fqdn..."
            }
            Catch {
                Write-Host "Generating Certificate for $fqdn Failed: $($_.Exception.Message)"
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Error" -EventMessage "Generating Certificate for $fqdn Failed: $($_.Exception.Message)"
            }
            Try {
                Write-Host "Submitting Certificate for $fqdn..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Information" -EventMessage "Submitting Certificate for $fqdn..."
                Submit-ACMECertificate $certalias -ErrorAction Stop
                Write-Host "Submitted Certificate for $fqdn..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Information" -EventMessage "Submitted Certificate for $fqdn..."
            }
            Catch {
                Write-Host "Submitting Certificate for $fqdn failed..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Error" -EventMessage "Submitting Certificate for $fqdn failed: $($_.Exception.Message)"
            }
            $ValidIssuer = (Update-ACMECertificate $certalias).IssuerSerialNumber
            if ($ValidIssuer -eq '') {
                ValidIssuer -domain $fqdn
            }else{
                WriteFileEventLog  -EventCat "Certificate Check" -EventType "Information" -EventMessage "Issuer Validation succeeded directly, Issuer Serial Number: $ValidIssuer"
                Write-Host "IssuerSerialNumber: $ValidIssuer" 
                GrabCerts -domain $fqdn
            }
            Write-Host ""
            
        } else {
            WriteFileEventLog -EventBreak "True"
            WriteFileEventLog -EventBreak "True"
            $subdomains = Get-Content $domainname.FullName
            $sd_count = $subdomains.Count
            $subcount = 0
            $subdomainaliasses = @()
            Foreach ($subdomain in $subdomains) {
                $fqdn = "$subdomain.$domain"
                $subcount += 1
                if ($subcount -eq $sd_count) {
                    $subdomainaliasses += "a-$fqdn-$date"
                } else {
                    $subdomainaliasses += "a-$fqdn-$date"
                }
            }
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Write-Host "Check ACME Status"
            $Cert = (Update-ACMEIdentifier $domainalias -ChallengeType dns-01).Challenges | Where-Object {$_.Type -eq "dns-01"}
            $CertStatus = $Cert.Status
            Write-Host "Identifier Status: $CertStatus"
            Write-Host ""
            Write-Host "---------------------------------------------------"
            Write-Host ""
            Try {
                Write-Host "Generating Certificate for $domain..."
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Information" -EventMessage "Generating Certificate for $domain..."
                New-ACMECertificate $domainalias -Generate -AlternativeIdentifierRefs @($subdomainaliasses) -Alias $certalias -ErrorAction Stop
                Write-Host "Generated Certificate for $domain..."
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Information" -EventMessage "Generated Certificate for $domain..."
            }
            Catch {
                Write-Host "Generating Certificate for $domain Failed: $($_.Exception.Message)"
                WriteFileEventLog  -EventCat "Certificate Generate" -EventType "Error" -EventMessage "Generating Certificate for $domain Failed: $($_.Exception.Message)"
            }
            Try {
                Write-Host "Submitting Certificate for $domain..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Information" -EventMessage "Submitting Certificate for $domain..."
                Submit-ACMECertificate $certalias -ErrorAction Stop
                Write-Host "Submitted Certificate for $domain..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Information" -EventMessage "Submitted Certificate for $domain..."
            }
            Catch {
                Write-Host "Submitting Certificate for $domain failed..."
                WriteFileEventLog  -EventCat "Certificate Submit" -EventType "Error" -EventMessage "Submitting Certificate for $domain failed: $($_.Exception.Message)"
            }
            $ValidIssuer = (Update-ACMECertificate $certalias).IssuerSerialNumber
            if ($ValidIssuer -eq '') {
                ValidIssuer -domain $domain
            }else{
                WriteFileEventLog  -EventCat "Certificate Check" -EventType "Information" -EventMessage "Issuer Validation succeeded directly, Issuer Serial Number: $ValidIssuer"
                Write-Host "IssuerSerialNumber: $ValidIssuer" 
                GrabCerts -domain $domain
            }
            Write-Host ""
            
        }
        WriteFileEventLog -EventBreak "True"
        WriteFileEventLog -EventBreak "True"
    }
}    


if ($option -eq '') {
    Verify
    Start-Sleep 5
    SubmitChallenge
    Start-Sleep 2
    Status
    Start-Sleep 2
    GetCert
    Start-Sleep 2
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
if ($option -eq "RemoveTXT"){
    RemoveTXT
}
if ($option -eq "SubmitChallenge"){
    SubmitChallenge
}
if ($option -eq "GrabCerts") {
    GrabCerts -domain $domain
}