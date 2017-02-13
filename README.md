# LetsEncrypt-PowerShell
Get Let's Encrypt certificates by using a PowerShell and some .txt files in a directory.

*Please note, this project was made for learning purposes only.*
*If you need some more information, check the* **"Related"** *section below.*

This project has been made using the ACMESharp library.

* To use this script as-is, you need to install the [ACMESharp PowerShell Module](https://github.com/ebekker/ACMESharp/wiki/Quick-Start).
 * You need to follow the first 4 steps.
* You also need to make the directory: C:\Central_SSLStore\domains\
 * In this directory you make .txt files with the domainname as filename.
 * I.E.:  example.com.txt makes the domain: example.com
 * In this file you specify subdomains, see the [example.com.txt](https://github.com/MaddestScience/LetsEncrypt-PowerShell/blob/master/Central_SSLStore/domains/example.com.txt)
* Usage: powershell -command letsencrypt.ps1 -option [Verify/Status/CompleteChallenge/GetCert]

## Related

For documentation and getting started, go to the [ACMESharp wiki](https://github.com/ebekker/ACMESharp/wiki) which includes the [ACMESharp FAQ](https://github.com/ebekker/ACMESharp/wiki/FAQ).


Check out these other related projects:

* An [alternative simple ACME client for Windows](https://github.com/Lone-Coder/letsencrypt-win-simple) which features:
  * simple usage for common scenarios
  * IIS support
  * automatic renewals
* A [GUI interface](https://github.com/webprofusion/Certify) to this project's PowerShell module
* The official [python ACME client](https://github.com/letsencrypt/letsencrypt) of the [Let's Encrypt] project
* The [ACME specification](https://github.com/ietf-wg-acme/acme) which brings this all together (under development)
* See other [contributions](https://github.com/ebekker/ACMESharp/wiki/Contributions)


## Quick Start

You can find an example of how to get started quickly [here](https://github.com/ebekker/ACMESharp/wiki/Quick-Start).


