param (
    $Method="GET",
    $Uri,
    $Headers = @{ "Content-Type"="application/json" },
    $Body = $null,
    $OutFile = "./response.json"
)
# convert the token to a ssecret credential
$token = ConvertTo-SecureString -String $env:REST_TOKEN -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "minestardevops",$token
# no spaces in uri's
$Uri = $Uri.replace(' ', '%20')
Write-Host "$Method >> $Uri >> $OutFile"
$response = $null
$retries = 5
do {
    try {
        $response = Invoke-RestMethod -Method $Method -Authentication Basic -Credential $creds -Uri $Uri -Headers $Headers -Body $Body
        $response | ConvertTo-Json -Depth 8 | Set-Content $OutFile 
        # support template usage. Indicates success and the pipeline can read the output file
        Write-Host "##vso[task.setvariable variable=invokeRestResult;]$true"
        # no need for any retries
        $retries = 0
    } catch {
        $retries--
        Write-Error $_.ErrorDetails
        Write-Host "##vso[task.setvariable variable=invokeRestResult;]$false"
    }
} while ($retries -gt 0)
# support for calling the script directly
return $response