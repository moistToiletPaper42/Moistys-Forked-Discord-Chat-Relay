param(
    [switch]$SkipCopy
)

$compiler = "$PSScriptRoot\tools\addons\sourcemod\scripting\spcomp64.exe"

if(-not $SkipCopy){
    Copy-Item -Path "$PSScriptRoot\tools" -Destination "$PSScriptRoot\linking" -Recurse -Force
}
Copy-Item -Path "$PSScriptRoot\addons" -Destination "$PSScriptRoot\linking\" -Recurse -Force
Copy-Item -Path "$PSScriptRoot\cfg" -Destination "$PSScriptRoot\linking\" -Recurse -Force

$targets = Resolve-Path -Path .\addons\sourcemod\scripting\*.sp

if($targets.Count -gt 1){
    Write-Host "Multiple targets found, please manually compile:"
    $targets | ForEach-Object {
        $name = Split-Path -Leaf $_
        Write-Host
        Write-Host "cd '$PSScriptRoot\linking\addons\sourcemod\scripting'"
        Write-Host "$compiler $name -i .\include"
    }
} else {
    cd "$PSScriptRoot\linking\addons\sourcemod\scripting"
    $targets | ForEach-Object {
        $name = Split-Path -Leaf $_
        Write-Host "Compiling $name"
        & $compiler ".\$name" -i .\include

        $basename = Split-Path -LeafBase $_
        $compiled = Resolve-Path -Path ".\$basename.smx"

        # Move compiled file to the correct location (.\addons\sourcemod\plugins)
        Move-Item -Path $compiled -Destination "$PSScriptRoot\addons\sourcemod\plugins" -Force
    }
    cd $PSScriptRoot
}
