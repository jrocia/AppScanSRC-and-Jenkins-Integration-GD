# Copyright 2024 HCL America
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

write-host "======== Step: Creating a config scan folder (auth) ========"
$sessionId=$(Invoke-WebRequest -Method "POST" -Headers @{"Accept"="application/json"} -ContentType 'application/json' -Body "{`"keyId`": `"$aseApiKeyId`",`"keySecret`": `"$aseApiKeySecret`"}" -Uri "https://$aseHostname`:9443/ase/api/keylogin/apikeylogin" -SkipCertificateCheck | Select-Object -Expand Content | ConvertFrom-Json | select -ExpandProperty sessionId);
# Get the aseAppId from ASE
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
$aseAppId=$(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/search?searchTerm=$aseAppName" -SkipCertificateCheck | ConvertFrom-Json).id;

$aseAppAtrib = $(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/$aseAppId" -SkipCertificateCheck|ConvertFrom-Json);
$checkScanConfig=$($aseAppAtrib.attributeCollection.attributeArray | Where-Object { $_.name -eq "Scan Configuration" } | Select-Object -ExpandProperty value)
if (-not [string]::IsNullOrWhiteSpace($checkScanConfig)) {
    Write-Host "Scan Configuration found in Appscan Enterprise: $checkScanConfig"
    $scanConfig=$($aseAppAtrib.attributeCollection.attributeArray | Where-Object { $_.name -eq "Scan Configuration" } | Select-Object -ExpandProperty value)
}
else {
    write-host "Using Scan Configuration $scanConfig."
}
Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/logout" -SkipCertificateCheck | Out-Null

# Creating Appscan Source script file. It is used with AppScanSrcCli to run scans reading folder content and selecting automatically the language (Open Folder command).
if ($compiledArtifactFolder -ne "none"){
  $content=Get-ChildItem -Path $compiledArtifactFolder -filter "*.zip"
  if ($content){
    write-host "There is a compiled files compressed in folder $compiledArtifactFolder."
    Expand-Archive -Path $content -DestinationPath $compiledArtifactFolder
  }else{
    write-host "There is no compiled files compressed."
  }
  # write-output "login_file $aseHostname `"$aseToken`" -acceptssl" > script.scan
  write-output "login_file $aseHostname $aseToken -acceptssl" > script.scan
  write-output "RUNAS AUTO" >> script.scan
  write-output "of `"$WorkingDirectory\$compiledArtifactFolder`"" >> script.scan
  write-output "sc `"$aseAppName-$BuildNumber.ozasmt`" -scanconfig `"$scanConfig`" -name `"$aseAppName-$BuildNumber`"" >> script.scan
  #write-output "report Findings pdf-detailed `"$aseAppName-$BuildNumber.pdf`" `"$aseAppName-$BuildNumber.ozasmt`" -includeSrcBefore:5 -includeSrcAfter:5 -includeTrace:definitive -includeTrace:suspect -includeHowToFix" >> script.scan
  write-output "pa `"$aseAppName-$BuildNumber.ozasmt`"" >> script.scan
  write-output "exit" >> script.scan
  
  write-host "Config file created for compiled folder ($WorkingDirectory\$compiledArtifactFolder)."
}
else{
  # write-output "login_file $aseHostname `"$aseToken`" -acceptssl" > script.scan
  write-output "login_file $aseHostname $aseToken -acceptssl" > script.scan
  write-output "RUNAS AUTO" >> script.scan
  write-output "of `"$WorkingDirectory`"" >> script.scan
  write-output "sc `"$aseAppName-$BuildNumber.ozasmt`" -scanconfig `"$scanConfig`" -name `"$aseAppName-$BuildNumber`" -sourcecodeonly true" >> script.scan
  #write-output "report Findings pdf-detailed `"$aseAppName-$BuildNumber.pdf`" `"$aseAppName-$BuildNumber.ozasmt`" -includeSrcBefore:5 -includeSrcAfter:5 -includeTrace:definitive -includeTrace:suspect -includeHowToFix" >> script.scan
  write-output "pa `"$aseAppName-$BuildNumber.ozasmt`"" >> script.scan
  write-output "exit" >> script.scan
  
  write-host "Config file created (source code only scan). Scan directory: $WorkingDirectory"
}
