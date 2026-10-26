$godot = "C:\Users\mkf11\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    $godot = "godot"
}
$targetDir = (Get-ChildItem -Directory -Path $PSScriptRoot | Where-Object { Test-Path (Join-Path $_.FullName "project.godot") }).FullName
& $godot --headless --path $targetDir -s tests/test_runner.gd
exit $LASTEXITCODE
