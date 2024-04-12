param (
    [String]$Organization,
    [String]$RepositoryId,
    [String]$SourceBranch,
    [Switch]$Debug
)

##
# Retrieve the semantic version number as an integer
#  $branch       : The name of the source branch
#  $releasePrefix: The 'release' or 'releases'
#  returns       : semver as integer, major version as integer
#
function semToValue {
    param (
        $branch,
        $releasePrefix
    )
    # you can't have version 0.0.0
    $versionAsInt = 0
    $majorAsInt = 0
    if ($branch -match "^([a-z]|[\/])*$($releasePrefix)\/(\d+\.)(\d+\.)(\*|\d+)$") {
        $parts = $branch.split('/')
        $nums = $parts[$parts.Count-1].split('.')
        if ($nums.count -eq 3) {
            # major.minor.patch => xxyyzz
            # x: 1-99 * 10000 = 01yyzz - 99yyzz
            $majorAsInt  = ([int]$nums[0]) * 10000
            $versionAsInt  = $majorAsInt
            # y: 0-99 * 100 = 00zz-99zz
            $versionAsInt += ([int]$nums[1]) * 100
            # z: 0-99 * 1 = 0-99
            $versionAsInt += ([int]$nums[2])
        }
    }
    if ($Debug) {
        Write-Host "semToValue: '$branch' -> '$versionAsInt'"
    }
    return $versionAsInt, $majorAsInt
}

function findNextSemver {
    param (
        $sourceBranch,
        $defaultBranch = "main",
        $releasePrefix = "release",
        $branches
    )

    $fromSemver, $fromMajor = semToValue -branch $sourceBranch -releasePrefix $releasePrefix
    # don't use any branch by default
    $nextSemver = ""
    if ($Debug) {
        Write-Host "sourceBranch: '$sourceBranch'"
        Write-Host "defaultBranch: '$defaultBranch'"
        Write-Host "branches: '$($branches.count)'"
        Write-Host "fromSemver: '$fromSemver'"
        Write-Host "releasePrefix: $releasePrefix"
    }
    if ($fromSemver -gt 0) {
        $verDiff = 1000000
        # unset if there are 1.0, 2.0, 3.0 versions and we are looking for a 1.0 or 2.0 change.
        # we assume we can merge to master, we can only merge to the next highest older version
        $canUseMaster = $true
        $branches.value.ForEach({
            $toSemver, $toMajor = semToValue -branch $($_.name) -releasePrefix $releasePrefix
            if ($Debug) {
                Write-Host "_: '$_'"
                Write-Host "toSemver: '$toSemver'"
            }
            # we can't go from major to major
            if ($fromMajor -eq $toMajor) {
                $diff = $toSemver - $fromSemver
                if (($toSemver -ne 0) -and ($diff -gt 0) -and ($diff -lt $verDiff)) {
                    $verDiff = $diff
                    $nextSemver = $($_.name)
                }
            } elseif ($toMajor -gt $fromMajor){
                # we can't go to master if a newer version exists
                $canUseMaster = $false
            }
        })
        if ($canUseMaster -and $nextSemver -eq "") {
            $nextSemver = $defaultBranch
        }
        if ($Debug) {
            Write-Host "default: $defaultBranch`nsemver: $fromSemver -> $nextSemver"
        }
    }
    return $nextSemver
}

function Get-RestApi {
    param(
        $uri
    )

    $token = ConvertTo-SecureString -String $env:REST_TOKEN -AsPlainText -Force
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "devops",$token
    if ($Debug) {
        Write-Host "Uri: $uri"
    }
    $response = Invoke-RestMethod -Method GET -Authentication Basic -Credential $creds -Uri $uri
    Return $response
}


function Assert-NextVersion {
    param (
        $Branch,
        $Branches,
        $Assert
    )

    $ver, $maj = findNextSemver -sourceBranch $Branch -branches $Branches
    if ($ver -ne $Assert) {
        Write-Host "≠ $Branch version '$ver' is not '$Assert'" -ForegroundColor Red
    } else {
        Write-Host "√ $Branch version is '$ver'" -ForegroundColor White
    }
}

function Validate-NextSemVer {
    $branches = @{
        value = @(
            @{ name = "release/1.0.0" },
            @{ name = "release/1.1.0" },
            @{ name = "release/1.2.0" },
            @{ name = "release/1.2.1" },
            @{ name = "release/2.0.0" },
            @{ name = "release/2.1.0" },
            @{ name = "release/2.1.1" },
            @{ name = "release/2.1.2" },
            @{ name = "release/3.0.0" },
            @{ name = "release/3.1.0" },
            @{ name = "release/5.10.0" },
            @{ name = "release/5.11.0" },
            @{ name = "release/5.11.1" },
            @{ name = "release/5.12.0" }
        )
    }

    Assert-NextVersion -Branch "release/1.1.0"  -Branches $branches -Assert "release/1.2.0"
    Assert-NextVersion -Branch "release/1.2.0"  -Branches $branches -Assert "release/1.2.1"
    Assert-NextVersion -Branch "release/1.2.1"  -Branches $branches -Assert ""
    Assert-NextVersion -Branch "release/2.0.0"  -Branches $branches -Assert "release/2.1.0"
    Assert-NextVersion -Branch "release/2.1.0"  -Branches $branches -Assert "release/2.1.1"
    Assert-NextVersion -Branch "release/2.1.1"  -Branches $branches -Assert "release/2.1.2"
    Assert-NextVersion -Branch "release/2.1.2"  -Branches $branches -Assert ""
    Assert-NextVersion -Branch "release/3.0.0"  -Branches $branches -Assert "release/3.1.0"
    Assert-NextVersion -Branch "release/3.1.0"  -Branches $branches -Assert ""
    Assert-NextVersion -Branch "release/5.10.0" -Branches $branches -Assert "release/5.11.0"
    Assert-NextVersion -Branch "release/5.11.0" -Branches $branches -Assert "release/5.11.1"
    Assert-NextVersion -Branch "release/5.11.1" -Branches $branches -Assert "release/5.12.0"
    Assert-NextVersion -Branch "release/5.12.0" -Branches $branches -Assert "main"
}

# work out the default branch for the repository
$response = Get-RestApi "https://dev.azure.com/$($Organization)/_apis/git/repositories/$($RepositoryId)?api-version=7.2-preview.1"
$defaultBranch = $response.DefaultBranch

# get the release prefix used by the source branch
$items = $SourceBranch.split('/')
$releasePrefix = $items[$items.Count-2]

# get the list of "release" branches, using the required source branch release prefix
$branches = Get-RestApi "https://dev.azure.com/$($Organization)/_apis/git/repositories/$($RepositoryId)/refs?filter=heads/$($releasePrefix)/&api-version=7.2-preview.1"
$TargetBranch = findNextSemver -sourceBranch $sourceBranch -branches $branches -defaultBranch $defaultBranch -releasePrefix $releasePrefix
if ($Debug) {
    Write-Host "Organization  = '$Organization'"
    Write-Host "RepositoryId  = '$RepositoryId'"
    Write-Host "SourcetBranch = '$SourceBranch'"
    Write-Host "targetBranch  = '$TargetBranch'"
}
Write-Host "##vso[task.setvariable variable=TargetBranch;]$TargetBranch"
Return $TargetBranch
