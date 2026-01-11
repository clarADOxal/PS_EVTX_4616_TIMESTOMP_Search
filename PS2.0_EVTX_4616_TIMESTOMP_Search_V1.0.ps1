cls
$Name="PS_EVTX_TIMESTOMP_Search"
$Version="1.4"

Write-Host "#############################################"
Write-Host " $Name - v$Version"
Write-Host "#############################################"
Get-Date
Write-Host ""
Write-Host -Fore "Slow Version for PowerShell 2.0"

# ─── DOSSIERS ───────────────────────────────────────────────
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$InPath  = Join-Path $ScriptPath "IN"
$OutPath = Join-Path $ScriptPath "OUT"

if (!(Test-Path $InPath))  { New-Item $InPath  -ItemType Directory | Out-Null }
if (!(Test-Path $OutPath)) { New-Item $OutPath -ItemType Directory | Out-Null }

$CsvOut = Join-Path $OutPath "TimeStomp_EVTX_Results.csv"

# ─── DEFINITIONS DES ID CIBLES ──────────────────────────────
$TargetIDs = @(4616, 1, 37, 6013, 35, 134)
$Targets = @{
    4616 = "Heure systeme modifiee";
    1    = "Heure systeme changee (Kernel-General)";
    37   = "Fuseau horaire modifie / Decalage NTP";
    6013 = "Uptime systeme";
    35   = "Synchronisation NTP reussie";
    134  = "Source NTP modifiee"
}

$Results = New-Object System.Collections.ArrayList

# ─── ANALYSE EVTX ───────────────────────────────────────────
$EvtxFiles = Get-ChildItem $InPath -Filter *.evtx
if ($null -eq $EvtxFiles) {
    Write-Host "Aucun fichier EVTX trouve dans IN\" -ForegroundColor Red
    exit
}

foreach ($Evtx in $EvtxFiles) {
    Write-Host "`nAnalyse : $($Evtx.Name)" -ForegroundColor Cyan
    
    try {
        # STRATEGIE ULTIME : On lit tout sans filtre, car le filtrage 
        # par parametre echoue sur cette version de PowerShell.
        $AllEvents = Get-WinEvent -Path $Evtx.FullName -ErrorAction SilentlyContinue

        if ($null -eq $AllEvents) { continue }

        foreach ($Evt in $AllEvents) {
            # Filtrage manuel par ID
            if ($TargetIDs -contains $Evt.Id) {
                
                $Desc = $Targets[$Evt.Id]
                $Xml = [xml]$Evt.ToXml()
                $OldTime = ""
                $NewTime = ""
                $Delta   = ""

                if ($Evt.Id -eq 4616) {
                    $Nodes = $Xml.Event.EventData.Data
                    foreach ($node in $Nodes) {
                        if ($node.Name -eq "OldTime") { $OldTime = $node."#text" }
                        if ($node.Name -eq "NewTime") { $NewTime = $node."#text" }
                    }
                    if ($OldTime -and $NewTime) {
                        try { 
                            $ts = ([datetime]$NewTime) - ([datetime]$OldTime) 
                            $Delta = [math]::Round($ts.TotalSeconds, 2).ToString() + " sec"
                        } catch { $Delta = "n/a" }
                    }
                }

                $Obj = New-Object PSObject
                $Obj | Add-Member -MemberType NoteProperty -Name "Date"        -Value $Evt.TimeCreated
                $Obj | Add-Member -MemberType NoteProperty -Name "EventID"     -Value $Evt.Id
                $Obj | Add-Member -MemberType NoteProperty -Name "Description" -Value $Desc
                $Obj | Add-Member -MemberType NoteProperty -Name "OldTime"     -Value $OldTime
                $Obj | Add-Member -MemberType NoteProperty -Name "NewTime"     -Value $NewTime
                $Obj | Add-Member -MemberType NoteProperty -Name "Delta"       -Value $Delta
                $Obj | Add-Member -MemberType NoteProperty -Name "Fichier"     -Value $Evtx.Name
                
                $null = $Results.Add($Obj)
            }
        }
    }
    catch {
        Write-Host "Erreur sur $($Evtx.Name) : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ─── EXPORT CSV ─────────────────────────────────────────────
if ($Results.Count -gt 0) {
    $Results | Sort-Object Date | Export-Csv $CsvOut -NoTypeInformation -Encoding UTF8
    Write-Host "`n[OK] $($Results.Count) evenements extraits dans : $CsvOut" -ForegroundColor Green
} else {
    Write-Host "`nAucun evenement detecte avec les IDs cibles." -ForegroundColor Yellow
}
