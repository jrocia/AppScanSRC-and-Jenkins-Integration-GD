# Copyright 2023 HCL America
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

write-host "======== Step: Checking Security Gate ========"
$scanName=(Get-Content .\scanName_var.txt);
# ASE Authentication getting sessionId
$sessionId=$(Invoke-WebRequest -Method "POST" -Headers @{"Accept"="application/json"} -ContentType 'application/json' -Body "{`"keyId`": `"$aseApiKeyId`",`"keySecret`": `"$aseApiKeySecret`"}" -Uri "https://$aseHostname`:9443/ase/api/keylogin/apikeylogin" -SkipCertificateCheck | Select-Object -Expand Content | ConvertFrom-Json | select -ExpandProperty sessionId);
# Get vulnerabilities total from ASE API and parse into json variable
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
$vulnSummary=$((Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"}-Uri "https://$aseHostname`:9443/ase/api/summaries/issues_v2?query=scanname%3D$scanName&group=Severity" -SkipCertificateCheck).content | ConvertFrom-json)
# Security Gate steps
[int]$criticalIssues = ($vulnSummary | Where {$_.tagName -eq 'Critical'}).numMatch
[int]$highIssues = ($vulnSummary | Where {$_.tagName -eq 'High'}).numMatch
[int]$mediumIssues = ($vulnSummary | Where {$_.tagName -eq 'Medium'}).numMatch
[int]$lowIssues = ($vulnSummary | Where {$_.tagName -eq 'Low'}).numMatch
[int]$infoIssues = ($vulnSummary | Where {$_.tagName -eq 'Information'}).numMatch
[int]$totalIssues = $highIssues+$mediumIssues+$lowIssues+$infoIssues

write-host "There is $highIssues high issues, $mediumIssues medium issues, $lowIssues low issues and $infoIssues informational issues."
write-host "The company policy permit less than $highIssuesAllowed high, $mediemIssuesAllowed medium or $lowIssuesAllowed low issues."

# Get the aseAppId from ASE
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
$aseAppId=$(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/search?searchTerm=$aseAppName" -SkipCertificateCheck | ConvertFrom-Json).id;

$aseAppAtrib = $(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/$aseAppId" -SkipCertificateCheck|ConvertFrom-Json);
$secGw=$($aseAppAtrib.attributeCollection.attributeArray | Where-Object { $_.name -eq "Security Gate" } | Select-Object -ExpandProperty value)
if ( $secGw -eq "Disabled" ) {
  write-host "Security Gate disabled.";
  exit 0
  }
write-host "Security Gate enabled.";

if (( $highIssues -gt $highIssuesAllowed ) -or ( $mediumIssues -gt $mediumIssuesAllowed ) -or ( $lowIssues -gt $lowIssuesAllowed )) {
  write-host "Security Gate build failed";
  exit 1
  }
else{  
write-host "Security Gate passed"
  }

Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/logout" -SkipCertificateCheck | Out-Null

# If you want to delete every files after execution
# Remove-Item -path $CI_PROJECT_DIR\* -recurse -exclude *.pdf,*.json,*.xml -force
