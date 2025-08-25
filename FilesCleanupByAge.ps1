param(
  [Parameter(Mandatory=$true)]
  [string] $StorageAccountName,          # ex.: mystorageacct

  [Parameter(Mandatory=$true)]
  [string] $ShareName,                   # ex.: fileshare1

  [int] $Days = 30,                      # idade mínima (em dias) para deletar

  [string] $StartPath = "",              # subpasta inicial ("" = raiz)

  [string[]] $ExcludeFolders = @(),      # nomes/prefixos de pastas a pular (opcional)

  [string[]] $IncludeExtensions = @(),   # ex.: @(".log",".tmp") para deletar só essas (opcional)

  [switch] $WhatIfMode                   # testa sem deletar
)

Write-Output "Autenticando com Managed Identity..."
Connect-AzAccount -Identity | Out-Null

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
if (-not $ctx) { throw "Falha ao criar contexto de Storage." }

$cutoff = [DateTimeOffset]::UtcNow.AddDays(-[double]$Days)
Write-Output "Share: $ShareName | StartPath: '$StartPath' | Cutoff (UTC): $cutoff | WhatIf: $($WhatIfMode.IsPresent)"

function ShouldSkipFolder([string]$relPath) {
    if (-not $ExcludeFolders -or $ExcludeFolders.Count -eq 0) { return $false }
    foreach ($ex in $ExcludeFolders) {
        if ($relPath -like "$ex*" -or $relPath.Split('/')[0] -eq $ex) { return $true }
    }
    return $false
}

function ShouldKeepByExtension([string]$filePath) {
    if (-not $IncludeExtensions -or $IncludeExtensions.Count -eq 0) { return $true } # sem filtro = mantém todos
    $ext = [System.IO.Path]::GetExtension($filePath)
    return $IncludeExtensions -contains $ext
}

$queue = New-Object System.Collections.Generic.Queue[string]
$start = $StartPath.Trim('/')
$queue.Enqueue($start)

$allFiles = New-Object System.Collections.Generic.List[object]

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    if ([string]::IsNullOrEmpty($current)) { $current = "" }

    if (ShouldSkipFolder($current)) {
        Write-Output "Pulando pasta (excluída): '$current'"
        continue
    }

    try {
        $entries = Get-AzStorageFile -Context $ctx -ShareName $ShareName -Path $current -ErrorAction Stop
    } catch {
        Write-Warning "Falha ao listar '$current' – $_"
        continue
    }

    foreach ($e in $entries) {
        if ($e.IsDirectory) {
            $sub = [string]::IsNullOrEmpty($current) ? $e.Name : "$current/$($e.Name)"
            $queue.Enqueue($sub)
        } else {
            $rel = [string]::IsNullOrEmpty($current) ? $e.Name : "$current/$($e.Name)"

            try {
                $props = Get-AzStorageFile -Context $ctx -ShareName $ShareName -Path $rel -ErrorAction Stop
                $lm = $props.Properties.LastModified
            } catch {
                Write-Warning "Falha ao obter propriedades de '$rel' – $_"
                continue
            }

            if (-not (ShouldKeepByExtension($rel))) { continue }

            $allFiles.Add([pscustomobject]@{
                RelativePath = $rel
                LastModified = $lm
            }) | Out-Null
        }
    }
}

Write-Output ("Arquivos encontrados: {0}" -f $allFiles.Count)

$toDelete = $allFiles | Where-Object { $_.LastModified -lt $cutoff }
Write-Output ("Candidatos a exclusão (< {0:u}): {1}" -f $cutoff, $toDelete.Count)

[int]$ok = 0
[int]$fail = 0

foreach ($item in $toDelete) {
    $msg = "Delete: {0} (LastModified: {1:u})" -f $item.RelativePath, $item.LastModified
    if ($WhatIfMode) {
        Write-Output "[WHATIF] $msg"
    } else {
        try {
            Remove-AzStorageFile -Context $ctx -ShareName $ShareName -Path $item.RelativePath -Force -ErrorAction Stop
            Write-Output $msg
            $ok++
        }
        catch {
            Write-Warning ("Falha ao deletar '{0}': {1}" -f $item.RelativePath, $_.Exception.Message)
            $fail++
        }
    }
}

Write-Output ("Resumo – Sucesso: {0} | Falhas: {1}" -f $ok, $fail)
Write-Output "Concluído."
