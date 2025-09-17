param(
    [string]$ConfigPath = "/config/test.xml",
    [switch]$Latest
)

# Objetivo: iniciar um novo teste Tsung, aguardar terminar, gerar relatórios (dygraph)
# e criar a página index_viewer.html automaticamente.
# Pré-requisitos: docker compose em execução com serviços 'tsung' e 'viewer'.

$ErrorActionPreference = "Stop"

function Invoke-InContainer {
    param([string]$Cmd)
    docker compose exec tsung bash -lc $Cmd
}

Write-Host "[start-run] Iniciando novo teste com config: $ConfigPath"
Invoke-InContainer "tsung -f $ConfigPath start"

# Descobrir diretório do run mais recente
$runDir = (Invoke-InContainer "ls -1 /root/.tsung/log | tail -n 1").Trim()
if (-not $runDir) {
    throw "Não foi possível identificar o diretório do run."
}
Write-Host "[start-run] Run detectado: $runDir"

# Aguardar finalização (No more active users / OK to stop)
Write-Host "[start-run] Aguardando finalização do teste..."
$maxWaitSec = 900  # até 15 minutos
$elapsed = 0
$poll = 5
$finished = $false
while ($elapsed -lt $maxWaitSec) {
    $status = Invoke-InContainer "grep -E 'No more active users|OK to stop' /root/.tsung/log/$runDir/tsung_controller*.log || true"
    if ($status) { $finished = $true; break }
    Start-Sleep -Seconds $poll
    $elapsed += $poll
}
if (-not $finished) {
    Write-Warning "[start-run] Timeout aguardando término do teste. Continuando para gerar relatórios mesmo assim."
}

# Gerar relatórios (dygraph)
Write-Host "[start-run] Gerando relatórios..."
Invoke-InContainer "cd /root/.tsung/log/$runDir && /usr/lib/tsung/bin/tsung_stats.pl --dygraph ."

# Criar index_viewer.html
Write-Host "[start-run] Gerando index_viewer.html..."
Invoke-InContainer "bash /create_index.sh '$runDir' '/root/.tsung/log/$runDir'"

# Exibir links úteis
$viewerUrl = "http://localhost:8080/results/$runDir/index_viewer.html"
$reportUrl = "http://localhost:8080/results/$runDir/report.html"
$graphUrl = "http://localhost:8080/results/$runDir/graph.html"
$dashUrl = "http://localhost:8091/"

Write-Host "[start-run] Concluído! Acesse:" -ForegroundColor Green
Write-Host " - Dashboard: $dashUrl"
Write-Host " - Index do run: $viewerUrl"
Write-Host " - Relatório: $reportUrl"
Write-Host " - Gráficos: $graphUrl"

if ($Latest) {
    Write-Host "[start-run] (Opcional) Você passou -Latest: posso criar/atualizar um atalho 'latest.txt' com o nome do run."
}
