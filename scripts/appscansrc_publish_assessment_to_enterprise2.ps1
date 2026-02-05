# Getting and writing the scanName in a file
$scanName="$aseAppName`-$BuildNumber"
write-output $scanName > scanName_var.txt

$ozasmtFile = Get-ChildItem -Filter *.ozasmt -Name
# Load Ozasmt file in a variable and get the aseAppName
try{
	[XML]$ozasmt = Get-Content $ozasmtFile -ErrorAction stop;
}
catch{
	write-output "There is no OZASMT file.";
	break;
}
$aseAppName=$ozasmt.assessmentrun.assessmentconfig.application.name
write-host "The application name is $aseAppName"
# ASE authentication
$sessionId=$(Invoke-WebRequest -Method "POST" -Headers @{"Accept"="application/json"} -ContentType 'application/json' -Body "{`"keyId`": `"$aseApiKeyId`",`"keySecret`": `"$aseApiKeySecret`"}" -Uri "https://$aseHostname`:9443/ase/api/keylogin/apikeylogin" -SkipCertificateCheck | Select-Object -Expand Content | ConvertFrom-Json | select -ExpandProperty sessionId);
# Looking for $aseAppName into ASE
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
$aseAppId=$(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/search?searchTerm=$aseAppName" -SkipCertificateCheck | ConvertFrom-Json).id;
# If $aseAppName is Null create the application into ASE else just get the aseAppId
if ([string]::IsNullOrWhitespace($aseAppId)){
	$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
	$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
	$aseAppId=$(Invoke-WebRequest -Method POST -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -ContentType "application/json" -Body "{`"name`":`"$aseAppName`" }" -Uri "https://$aseHostname`:9443/ase/api/applications" -SkipCertificateCheck | ConvertFrom-Json).id;
	write-host "Application $aseAppName registered with id $aseAppId"
	sleep 3
    }
else{
	write-host "There is a registered application."
	}
$Form = [ordered]@{
	scanName = $scanName
	uploadedfile = Get-Item -Path $ozasmtFile
	}
# Import ozasmt file 
Invoke-WebRequest -Method Post -Form $Form -Headers @{"Asc_xsrf_token"="$sessionId"} -WebSession $session -Uri "https://$aseHostname`:9443/ase/api/issueimport/$aseAppId/6/" -SkipCertificateCheck | Out-Null;
#Invoke-WebRequest -Method Post -Form @{"scanName"="$scanName";"uploadedfile"=Get-Item -Path $ozasmtFile;} -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId";"X-Requested-With"="XMLHttpRequest";"ContentType"="text/plain"}  -Uri "https://$aseHostname`:9443/ase/api/issueimport/$aseAppId/6/" -SkipCertificateCheck | Out-Null;
# Rename imported file
$ozasmtFile=$ozasmtFile.replace('.\','')
Rename-Item -Path "$ozasmtFile" -NewName "imported-$ozasmtFile"
write-host "$ozasmtFile file with scanName $scanName imported in Application $aseAppName";
# ASE Logout session
Invoke-WebRequest -Method GET -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId";"X-Requested-With"="XMLHttpRequest"}  -Uri "https://$aseHostname`:9443/ase/api/logout" -SkipCertificateCheck | Out-Null;
