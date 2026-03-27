$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$InPath  = Join-Path $ScriptPath "IN"
$OutPath = Join-Path $ScriptPath "OUT"

# Création des dossiers si nécessaire
if (!(Test-Path $InPath))  { New-Item $InPath  -ItemType Directory | Out-Null }
if (!(Test-Path $OutPath)) { New-Item $OutPath -ItemType Directory | Out-Null }

$CsvOut = Join-Path $OutPath "TimeStomp_Results.csv"

# --- CHOIX DE LA SOURCE ---
# Pour analyser la machine locale, décommentez la ligne $SourcePath = "LIVE"
# $SourcePath = "LIVE" 
$SourcePath = Get-ChildItem -Path $InPath -Filter "Security.evtx" | Select-Object -ExpandProperty FullName -First 1

if (!$SourcePath) { 
    Write-Host "Aucun fichier Security.evtx dans /IN. Passage en mode LIVE (Admin requis)." -ForegroundColor Yellow
    $SourceParams = @{ LogName = "Security" }
} else {
    Write-Host "Analyse du fichier : $SourcePath" -ForegroundColor Cyan
    $SourceParams = @{ Path = $SourcePath }
}

# --- RECHERCHE ET CALCUL ---
try {
    $events = Get-WinEvent @SourceParams -FilterXPath "*[System[(EventID=4616)]]" -ErrorAction Stop
} catch {
    Write-Host "Aucun EventID 4616 trouvé ou accès refusé." -ForegroundColor Red
    exit
}

$results = foreach ($event in $events) {
    $xml = [xml]$event.ToXml()
    $oldTimeStr = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "PreviousTime" })."#text"
    $newTimeStr = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "NewTime" })."#text"
    $process  = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "ProcessName" })."#text"

    if ($oldTimeStr -and $newTimeStr) {
        $dtOld = [DateTime]$oldTimeStr
        $dtNew = [DateTime]$newTimeStr
        $diff  = $dtNew - $dtOld
        
        [PSCustomObject]@{
            DateEvenement = $event.TimeCreated
            AncienneHeure = $dtOld
            NouvelleHeure = $dtNew
            DecalageHeures = [Math]::Round($diff.TotalHours, 4)
            DecalageMinutes = [Math]::Round($diff.TotalMinutes, 2)
            Processus      = $process
            Utilisateur    = $event.UserId
        }
    }
}

# --- SORTIE ---
$results | Export-Csv -Path $CsvOut -NoTypeInformation -Delimiter ";" -Encoding UTF8
$results | Format-Table DateEvenement, DecalageHeures, Processus -AutoSize

Write-Host "`nTerminé. Rapport dispo ici : $CsvOut" -ForegroundColor Green