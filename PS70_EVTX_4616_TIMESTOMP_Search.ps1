# ─── LABEL CREATION ────────────────────────────────────────────────
cls
$Name="PS_EVTX_4616_TIMESTOMP_Search"
$version="0.6"
$Creation_Date = "06:00 19/08/2025"

#Delete unused method
#───────────────
$Creation_How = "Gemini+Humain Brain + ChatGPT"

#Logo Exemple
#─────────
$Logo = "  ___`n / | \`n(  .--)`n \___/`n"

#Todo
#───
$Todo="To Do"
$Todo+="0.1 - First time event check"
$Todo+="0.2 - Export as csv file"
$Todo+="0.3 - Ajout détection effacement journaux (1102/104)"
$Todo+="0.4 - Support de tous les .evtx du dossier IN"
$Todo+="0.5 - Exportation CSV consolidée avec Delta pour 4616"
$Todo+="0.6 - Add clear evtx and export"
#Label
#────
if (($Name.Length) -gt ($version.Length)){
	$fior1=$Name.Length+10;
	$fior2=($name.length)-($name.length)
	$fior3=($name.length)-($version.length)
} else {
	$fior1=$version.length+10;
	$fior2=($version.length)-($name.length)
	$fior3=(($version.length)-($version.length))
}

$fior1result="";for ($j=1; $j -le $fior1; $j++) { $fior1result+="#" }
$fior2result="";for ($j=1; $j -le $fior2; $j++) { $fior2result+=" " }
$fior3result="";for ($j=1; $j -le $fior3; $j++) { $fior3result+=" " }

write-host $fior1result
write-host "####"$Name$fior2result" ####"
write-host "####"$version$fior3result" ####"
write-host $fior1result
get-date -displayHint Time
write-host $Logo

sleep
cls

# ─── FOLDER CREATION ────────────────────────────────────────────────

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($dir in "IN","OUT") {
    $FullPath = Join-Path $ScriptPath $dir
    if (-Not (Test-Path $FullPath)) { New-Item $FullPath -ItemType Directory | Out-Null }
}

# ─── CONFIGURATION ────────────────────────────────────────────────
$LogFolderPath = ".\IN"
$OutputCsvPath = ".\OUT\Resultats_Analyse_EVTX.csv"
write-host -fore blue "Analyse de tous les fichiers EVTX dans : $LogFolderPath"

# ─── RUN ────────────────────────────────────────────────

cls

$EvtxFiles = Get-ChildItem -Path $LogFolderPath -Filter *.evtx
if ($EvtxFiles.Count -eq 0) {
    Write-Host "Aucun fichier .evtx trouvé dans '$LogFolderPath'." -ForegroundColor Red
    exit
}

$EventIDsTimeChange = 4616
$EventIDsClearLogs  = 1102,104

$Results = @()

foreach ($LogFile in $EvtxFiles) {
    Write-Host "`n=== Analyse du fichier : $($LogFile.Name) ===" -ForegroundColor Cyan

    try {
        $Events = Get-WinEvent -Path $LogFile.FullName -ErrorAction Stop

        # ─── PARTIE 1 : 4616 (Time Change) ────────────────────────────────
        $Events4616 = $Events | Where-Object { $_.Id -eq $EventIDsTimeChange }
        Write-Host "Nombre d'événements 4616 trouvés : $($Events4616.Count)" -ForegroundColor Green

        if ($Events4616.Count -gt 0) {
            $Events4616 | ForEach-Object {
                Write-Host "--------------------------------------------------"
                Write-Host -fore green "Computer : $($_.MachineName)"
                Write-Host "Event Date : $($_.TimeCreated)"
                Write-Host "User Account : $($_.Properties[0].Value)"
                Write-Host "Account Name : $($_.Properties[1].Value)"
                Write-Host "Domain : $($_.Properties[2].Value)"
                Write-Host "Change reason : $($_.Properties[3].Value)"
                Write-Host "Hour1 : $($_.Properties[4].Value)"
                Write-Host "Hour2 : $($_.Properties[5].Value)"

                $oldTimeDT = [datetime]$($_.Properties[4].Value)
                $newTimeDT = [datetime]$($_.Properties[5].Value)
                $timeDelta = $newTimeDT - $oldTimeDT

                Write-Host -fore red "Delta H2-H1 : $timeDelta"
                Write-Host "Nom Proc : $($_.Properties[7].Value)"

                $Results += [PSCustomObject]@{
                    FichierEVTX  = $LogFile.Name
                    LogName      = $_.LogName
                    EventID      = $_.Id
                    Date         = $_.TimeCreated
                    Machine      = $_.MachineName
                    Utilisateur  = $_.Properties[0].Value
                    Message      = $_.Message
                    TypeEvenement= "TimeChange"
                    Delta        = $timeDelta
                }
            }
        }

        # ─── PARTIE 2 : 1102 / 104 (Effacement de journaux) ────────────────────────────────
        $ClearEvents = $Events | Where-Object { $EventIDsClearLogs -contains $_.Id }
        Write-Host "`nNombre d'événements d'effacement trouvés (1102/104) : $($ClearEvents.Count)" -ForegroundColor Yellow

        if ($ClearEvents.Count -gt 0) {
            $ClearEvents | ForEach-Object {
                Write-Host "--------------------------------------------------"
                Write-Host -fore cyan "Journal : $($_.LogName)"
                Write-Host "Event ID : $($_.Id)"
                Write-Host "Date : $($_.TimeCreated)"
                Write-Host "Computer : $($_.MachineName)"
                if ($_.Properties.Count -gt 1) {
                    Write-Host "Utilisateur : $($_.Properties[1].Value)"
                }
                if ($_.Properties.Count -gt 2) {
                    Write-Host "Machine liée : $($_.Properties[2].Value)"
                }
                Write-Host "Message : $($_.Message)"

                $Results += [PSCustomObject]@{
                    FichierEVTX  = $LogFile.Name
                    LogName      = $_.LogName
                    EventID      = $_.Id
                    Date         = $_.TimeCreated
                    Machine      = $_.MachineName
                    Utilisateur  = if ($_.Properties.Count -gt 1) { $_.Properties[1].Value } else { "" }
                    Message      = $_.Message
                    TypeEvenement= "LogCleared"
                    Delta        = ""   # pas applicable
                }
            }
        }
    }
    catch {
        Write-Host "Erreur lors de la lecture du fichier $($LogFile.Name) : $_" -ForegroundColor Red
    }
}

# ─── EXPORT CSV ────────────────────────────────────────────────
if ($Results.Count -gt 0) {
    $Results | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n Résultats exportés dans : $OutputCsvPath" -ForegroundColor Green
} else {
    Write-Host "`n Aucun événement correspondant trouvé dans les journaux." -ForegroundColor Yellow
}

sleep
