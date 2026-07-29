[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $env:USERPROFILE "Desktop\PC_Analyzer_Report.html")
)

if (-not $OutputPath) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "PC_Analyzer_Report.html"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================================
# PROGRAMMATIC SPLASH SCREEN (no image file needed)
# ==========================================================
function Show-SplashScreen {
    param(
        [int]$Width = 500,
        [int]$Height = 300,
        [int]$DurationMs = 2500
    )

    $form = New-Object System.Windows.Forms.Form
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "None"
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.ClientSize = New-Object System.Drawing.Size($Width, $Height)
    $form.BackColor = [System.Drawing.Color]::FromArgb(11, 15, 25)  # #0b0f19

    # Paint event handler - draws gradient + text
    $paintHandler = {
        $g = $_.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        # Dark gradient background
        $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            [System.Drawing.Rectangle]::new(0, 0, $Width, $Height),
            [System.Drawing.Color]::FromArgb(11, 15, 25),
            [System.Drawing.Color]::FromArgb(30, 41, 59),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        $g.FillRectangle($gradient, 0, 0, $Width, $Height)
        $gradient.Dispose()

        # Accent line at top
        $accentPen = New-Object System.Drawing.Pen(
            [System.Drawing.Color]::FromArgb(96, 165, 250), 2
        )
        $g.DrawLine($accentPen, 0, 0, $Width, 0)
        $accentPen.Dispose()

        # Title
        $titleFont = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
        $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $titleSize = $g.MeasureString("PC Analyzer", $titleFont)
        $titleX = ($Width - $titleSize.Width) / 2
        $titleY = 80
        $g.DrawString("PC Analyzer", $titleFont, $titleBrush, $titleX, $titleY)
        $titleFont.Dispose()
        $titleBrush.Dispose()

        # Subtitle
        $subFont = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
        $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))
        $subSize = $g.MeasureString("Hardware Capability Assessment", $subFont)
        $subX = ($Width - $subSize.Width) / 2
        $subY = $titleY + 50
        $g.DrawString("Hardware Capability Assessment", $subFont, $subBrush, $subX, $subY)
        $subFont.Dispose()
        $subBrush.Dispose()

        # Loading dots
        $dotY = $Height - 60
        $dotSize = 8
        $dotSpacing = 20
        $totalDotsWidth = 3 * $dotSize + 2 * $dotSpacing
        $startX = ($Width - $totalDotsWidth) / 2

        for ($i = 0; $i -lt 3; $i++) {
            $alpha = 255 - ($i * 60)
            $dotColor = [System.Drawing.Color]::FromArgb($alpha, 96, 165, 250)
            $dotBrush = New-Object System.Drawing.SolidBrush($dotColor)
            $dotX = $startX + ($i * ($dotSize + $dotSpacing))
            $g.FillEllipse($dotBrush, $dotX, $dotY, $dotSize, $dotSize)
            $dotBrush.Dispose()
        }

        # Version text
        $verFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        $verBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(71, 85, 105))
        $verSize = $g.MeasureString("Portable Edition v1.0", $verFont)
        $verX = ($Width - $verSize.Width) / 2
        $g.DrawString("Portable Edition v1.0", $verFont, $verBrush, $verX, $Height - 30)
        $verFont.Dispose()
        $verBrush.Dispose()
    }

    $form.Add_Paint($paintHandler)

    # Timer to auto-close
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $DurationMs
    $timer.Add_Tick({
        $timer.Stop()
        $form.Close()
    })
    $timer.Start()

    # Show modal (runs message pump)
    $null = $form.ShowDialog()

    $timer.Dispose()
    $form.Dispose()
}

# --- SHOW SPLASH ---
Show-SplashScreen -Width 500 -Height 300 -DurationMs 2500

# ==========================================================
# CONFIGURATION (single source of truth for magic numbers)
# ==========================================================

$Script:MHzPerGHz = 1000

# Score awarded per component based on how it compares to requirements.
$Script:ScoreBands = @{
    BelowMinimum      = 25
    MeetsMinimum      = 65
    MeetsRecommended  = 100
}

# Thresholds for the color of the progress bar in the report.
$Script:ScoreColorThresholds = @{
    Excellent  = 85
    Acceptable = 60
}

$Script:ChartColors = @{
    Good = "#22c55e"
    Warn = "#f59e0b"
    Bad  = "#ef4444"
}

# Baseline hardware this tool nudges users toward when generating
# generic (non-catalog-specific) upgrade suggestions.
$Script:RecommendedBaselines = @{
    RamGB    = 16
    VramGB   = 4
    CpuCores = 8
}

# ==========================================================
# DOMAIN MODEL
# ==========================================================

enum ComponentStatus {
    BelowMinimum
    Minimum
    Recommended
}

enum VerdictLevel {
    NotRecommended
    Playable
    Excellent
}

class HardwareProfile {
    [string]$CpuName
    [int]$CpuCores
    [int]$CpuThreads
    [double]$CpuClockGHz
    [int]$RamGB
    [string]$GpuName
    [int]$GpuVramGB
    [string]$WindowsVersion
}

class StorageDevice {
    [string]$Name
    [string]$MediaType
    [int]$SizeGB
}

class SoftwareRequirement {
    [string]$Name
    [string]$Category
    [int]$MinRamGB
    [int]$RecRamGB
    [int]$MinCpuCores
    [int]$RecCpuCores
    [int]$MinVramGB
    [int]$RecVramGB
}

class AnalysisResult {
    [string]$Category
    [string]$Name
    [ComponentStatus]$RamStatus
    [ComponentStatus]$CpuStatus
    [ComponentStatus]$GpuStatus
    [int]$Score
    [VerdictLevel]$Verdict
}

class ReportData {
    [HardwareProfile]$Hardware
    [StorageDevice[]]$Storage
    [AnalysisResult[]]$Results
    [int]$GamingScore
    [int]$DevelopmentScore
    [System.Collections.Generic.List[string]]$Recommendations
}

# ==========================================================
# DATA COLLECTION
# ==========================================================

function Get-HardwareProfile {
    <#
    .SYNOPSIS
        Queries WMI/CIM for CPU, GPU, RAM, and OS details.
    .OUTPUTS
        HardwareProfile
    #>
    [CmdletBinding()]
    [OutputType([HardwareProfile])]
    param()

    try {
        $cpu    = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $gpu    = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -First 1
        $os     = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Unable to query hardware via WMI/CIM. Try running as Administrator.", $_.Exception)
    }

    if (-not $cpu -or -not $system -or -not $os) {
        throw [System.InvalidOperationException]::new(
            "WMI returned no data for CPU, OS, or system enclosure. Cannot continue.")
    }

    $profile = [HardwareProfile]::new()
    $profile.CpuName        = $cpu.Name.Trim()
    $profile.CpuCores       = [int]$cpu.NumberOfCores
    $profile.CpuThreads     = [int]$cpu.NumberOfLogicalProcessors
    $profile.CpuClockGHz    = [math]::Round($cpu.MaxClockSpeed / $Script:MHzPerGHz, 2)
    $profile.RamGB          = [math]::Round($system.TotalPhysicalMemory / 1GB)
    $profile.GpuName        = if ($gpu -and $gpu.Name) { $gpu.Name } else { "Unknown / Not Detected" }
    $profile.GpuVramGB      = if ($gpu -and $gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB) } else { 0 }
    $profile.WindowsVersion = $os.Caption

    return $profile
}

function Get-StorageDevices {
    <#
    .SYNOPSIS
        Enumerates physical disks. Returns an empty array (not $null) on
        failure so downstream code doesn't need null checks.
    .OUTPUTS
        StorageDevice[]
    #>
    [CmdletBinding()]
    [OutputType([StorageDevice[]])]
    param()

    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to enumerate physical disks: $($_.Exception.Message)"
        return @()
    }

    return @($disks | ForEach-Object {
        [StorageDevice]@{
            Name      = $_.FriendlyName
            MediaType = $_.MediaType
            SizeGB    = [math]::Round($_.Size / 1GB)
        }
    })
}

function Get-SoftwareCatalog {
    <#
    .SYNOPSIS
        The requirement catalog. This is the one place to add or edit
        software/game entries -- no analysis or rendering logic lives here
        (Open/Closed: extending the catalog never touches behavior code).
    .OUTPUTS
        SoftwareRequirement[]
    #>
    [OutputType([SoftwareRequirement[]])]
    param()

    $rawCatalog = @(
        @{ Name = "Android Studio";      Category = "Development"; MinRAM = 8; RecRAM = 16; MinCPU = 4; RecCPU = 8; MinVRAM = 1; RecVRAM = 2 }
        @{ Name = "Unity 2022";          Category = "Development"; MinRAM = 8; RecRAM = 16; MinCPU = 4; RecCPU = 8; MinVRAM = 2; RecVRAM = 4 }
        @{ Name = "Blender";             Category = "Development"; MinRAM = 8; RecRAM = 16; MinCPU = 4; RecCPU = 8; MinVRAM = 4; RecVRAM = 8 }
        @{ Name = "Visual Studio 2022";  Category = "Development"; MinRAM = 4; RecRAM = 16; MinCPU = 2; RecCPU = 8; MinVRAM = 1; RecVRAM = 1 }
        @{ Name = "GTA V";               Category = "Game";        MinRAM = 4; RecRAM = 8;  MinCPU = 4; RecCPU = 4; MinVRAM = 1; RecVRAM = 4 }
        @{ Name = "Tekken 7";            Category = "Game";        MinRAM = 6; RecRAM = 8;  MinCPU = 4; RecCPU = 4; MinVRAM = 2; RecVRAM = 4 }
        @{ Name = "Forza Horizon 5";     Category = "Game";        MinRAM = 8; RecRAM = 16; MinCPU = 4; RecCPU = 8; MinVRAM = 4; RecVRAM = 8 }
        @{ Name = "PUBG Mobile Emulator";Category = "Game";        MinRAM = 8; RecRAM = 16; MinCPU = 4; RecCPU = 8; MinVRAM = 2; RecVRAM = 4 }
    )

    return @($rawCatalog | ForEach-Object {
        [SoftwareRequirement]@{
            Name        = $_.Name
            Category    = $_.Category
            MinRamGB    = $_.MinRAM
            RecRamGB    = $_.RecRAM
            MinCpuCores = $_.MinCPU
            RecCpuCores = $_.RecCPU
            MinVramGB   = $_.MinVRAM
            RecVramGB   = $_.RecVRAM
        }
    })
}

# ==========================================================
# ANALYSIS
# ==========================================================

function Get-ComponentStatus {
    <#
    .SYNOPSIS
        Pure comparison: where does Current fall relative to Minimum/Recommended.
        No formatting, no HTML -- see Get-StatusDisplayText for presentation.
    #>
    [OutputType([ComponentStatus])]
    param(
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$Current,
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$Minimum,
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$Recommended
    )

    if ($Current -lt $Minimum) { return [ComponentStatus]::BelowMinimum }
    if ($Current -lt $Recommended) { return [ComponentStatus]::Minimum }
    return [ComponentStatus]::Recommended
}

function Get-ComponentScore {
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][ComponentStatus]$Status
    )

    switch ($Status) {
        ([ComponentStatus]::BelowMinimum)  { return $Script:ScoreBands.BelowMinimum }
        ([ComponentStatus]::Minimum)       { return $Script:ScoreBands.MeetsMinimum }
        ([ComponentStatus]::Recommended)   { return $Script:ScoreBands.MeetsRecommended }
    }
}

function Get-OverallVerdict {
    <#
    .SYNOPSIS
        Worst-component-wins verdict, computed against the ComponentStatus
        enum directly -- not against display strings. This is the fix for
        the original bug where "Below Minimum &#8595;" never matched
        "Below Minimum" and failing components were reported as passing.
    #>
    [OutputType([VerdictLevel])]
    param(
        [Parameter(Mandatory)][ComponentStatus[]]$Statuses
    )

    if ($Statuses -contains [ComponentStatus]::BelowMinimum) { return [VerdictLevel]::NotRecommended }
    if ($Statuses -contains [ComponentStatus]::Minimum)      { return [VerdictLevel]::Playable }
    return [VerdictLevel]::Excellent
}

function New-AnalysisResult {
    [OutputType([AnalysisResult])]
    param(
        [Parameter(Mandatory)][HardwareProfile]$Hardware,
        [Parameter(Mandatory)][SoftwareRequirement]$Requirement
    )

    $ramStatus = Get-ComponentStatus -Current $Hardware.RamGB     -Minimum $Requirement.MinRamGB    -Recommended $Requirement.RecRamGB
    $cpuStatus = Get-ComponentStatus -Current $Hardware.CpuCores  -Minimum $Requirement.MinCpuCores  -Recommended $Requirement.RecCpuCores
    $gpuStatus = Get-ComponentStatus -Current $Hardware.GpuVramGB -Minimum $Requirement.MinVramGB    -Recommended $Requirement.RecVramGB

    $averageScore = [int]((
        (Get-ComponentScore -Status $ramStatus) +
        (Get-ComponentScore -Status $cpuStatus) +
        (Get-ComponentScore -Status $gpuStatus)
    ) / 3)

    return [AnalysisResult]@{
        Category  = $Requirement.Category
        Name      = $Requirement.Name
        RamStatus = $ramStatus
        CpuStatus = $cpuStatus
        GpuStatus = $gpuStatus
        Score     = $averageScore
        Verdict   = Get-OverallVerdict -Statuses @($ramStatus, $cpuStatus, $gpuStatus)
    }
}

function Invoke-CatalogAnalysis {
    [OutputType([AnalysisResult[]])]
    param(
        [Parameter(Mandatory)][HardwareProfile]$Hardware,
        [Parameter(Mandatory)][SoftwareRequirement[]]$Catalog
    )

    return @($Catalog | ForEach-Object { New-AnalysisResult -Hardware $Hardware -Requirement $_ })
}

function Get-CategoryScore {
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][AnalysisResult[]]$Results,
        [Parameter(Mandatory)][string]$Category
    )

    $categoryResults = @($Results | Where-Object { $_.Category -eq $Category })
    if ($categoryResults.Count -eq 0) { return 0 }
    return [int]($categoryResults | Measure-Object -Property Score -Average).Average
}

function Get-UpgradeRecommendations {
    [OutputType([System.Collections.Generic.List[string]])]
    param(
        [Parameter(Mandatory)][HardwareProfile]$Hardware,
        [Parameter(Mandatory)][StorageDevice[]]$Storage
    )

    $recommendations = [System.Collections.Generic.List[string]]::new()

    if ($Hardware.RamGB -lt $Script:RecommendedBaselines.RamGB) {
        $recommendations.Add("Upgrade RAM to $($Script:RecommendedBaselines.RamGB)GB or higher")
    }
    if ($Hardware.GpuVramGB -lt $Script:RecommendedBaselines.VramGB) {
        $recommendations.Add("Upgrade GPU to at least $($Script:RecommendedBaselines.VramGB)GB VRAM")
    }
    if ($Hardware.CpuCores -lt $Script:RecommendedBaselines.CpuCores) {
        $recommendations.Add("Upgrade to an $($Script:RecommendedBaselines.CpuCores)-core CPU for modern workloads")
    }
    if (-not ($Storage | Where-Object { $_.MediaType -match "SSD" })) {
        $recommendations.Add("Install an SSD for significantly faster performance")
    }
    if ($recommendations.Count -eq 0) {
        $recommendations.Add("No major upgrades recommended")
    }

    return $recommendations
}

# ==========================================================
# PRESENTATION (status/verdict -> display text is isolated here,
# deliberately separate from the enums above)
# ==========================================================

function Get-VerdictRowClass {
    [OutputType([string])]
    param([Parameter(Mandatory)][VerdictLevel]$Verdict)

    switch ($Verdict) {
        ([VerdictLevel]::Excellent) { return "row-good" }
        ([VerdictLevel]::Playable)  { return "row-warn" }
        default                     { return "row-bad" }
    }
}

function Get-StatusDisplayText {
    [OutputType([string])]
    param([Parameter(Mandatory)][ComponentStatus]$Status)

    switch ($Status) {
        ([ComponentStatus]::BelowMinimum) { return '<span class="status status-below">Below Minimum &#8595;</span>' }
        ([ComponentStatus]::Minimum)      { return '<span class="status status-min">Minimum</span>' }
        ([ComponentStatus]::Recommended)  { return '<span class="status status-rec">Recommended &check;</span>' }
    }
}

function Get-VerdictDisplayText {
    [OutputType([string])]
    param([Parameter(Mandatory)][VerdictLevel]$Verdict)

    switch ($Verdict) {
        ([VerdictLevel]::NotRecommended) { return '<span class="verdict verdict-bad">Not Recommended &#10008;</span>' }
        ([VerdictLevel]::Playable)       { return '<span class="verdict verdict-playable">Playable / Usable</span>' }
        ([VerdictLevel]::Excellent)      { return '<span class="verdict verdict-excellent">Excellent</span>' }
    }
}

function ConvertTo-StorageTableRows {
    [OutputType([string])]
    param([Parameter(Mandatory)][StorageDevice[]]$Devices)

    $rows = $Devices | ForEach-Object {
        $dotClass = if ($_.MediaType -match "SSD") { "dot-ssd" } else { "dot-hdd" }
        $badgeClass = if ($_.MediaType -match "SSD") { "badge-ssd" } else { "badge-hdd" }
        '<tr><td><div class="cell-flex"><span class="dot ' + $dotClass + '"></span>' + $_.Name + '</div></td><td><span class="badge ' + $badgeClass + '">' + $_.MediaType + '</span></td><td>' + $_.SizeGB + ' GB</td></tr>'
    }
    return ($rows -join "`n")
}

function ConvertTo-RecommendationListItems {
    [OutputType([string])]
    param([Parameter(Mandatory)][string[]]$Recommendations)

    return (($Recommendations | ForEach-Object { '<li><span class="rec-icon">&#10003;</span>' + $_ + '</li>' }) -join "`n")
}

function Get-ScoreBarColor {
    [OutputType([string])]
    param([Parameter(Mandatory)][ValidateRange(0, 100)][int]$Score)

    if ($Score -ge $Script:ScoreColorThresholds.Excellent)  { return $Script:ChartColors.Good }
    if ($Score -ge $Script:ScoreColorThresholds.Acceptable) { return $Script:ChartColors.Warn }
    return $Script:ChartColors.Bad
}

function ConvertTo-AnalysisTableRows {
    <#
    .SYNOPSIS
        Single row-rendering function shared by the Development and Game
        tables. Replaces the two copy-pasted loops in the original script --
        filter the results before calling this, don't duplicate the loop.
    #>
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AnalysisResult[]]$Results
    )

    $builder = [System.Text.StringBuilder]::new()

    foreach ($result in $Results) {
        $rowClass    = Get-VerdictRowClass -Verdict $result.Verdict
        $barColor    = Get-ScoreBarColor -Score $result.Score
        $verdictText = Get-VerdictDisplayText -Verdict $result.Verdict

        [void]$builder.Append(@"
<tr class='$rowClass'>
<td>$($result.Name)</td>
<td>$(Get-StatusDisplayText -Status $result.RamStatus)</td>
<td>$(Get-StatusDisplayText -Status $result.CpuStatus)</td>
<td>$(Get-StatusDisplayText -Status $result.GpuStatus)</td>
<td>$verdictText</td>
<td>
<div class='progress'>
<div class='progress-fill' style='width:$($result.Score)%;background:$barColor'>$($result.Score)%</div>
</div>
</td>
</tr>
"@)
    }

    return $builder.ToString()
}

function ConvertTo-StorageTableRows {
    [OutputType([string])]
    param([Parameter(Mandatory)][StorageDevice[]]$Devices)

    $rows = $Devices | ForEach-Object {
        $dotClass = if ($_.MediaType -match "SSD") { "dot-ssd" } else { "dot-hdd" }
        $badgeClass = if ($_.MediaType -match "SSD") { "badge-ssd" } else { "badge-hdd" }
        "<tr><td><div class='cell-flex'><span class='dot $dotClass'></span>$($_.Name)</div></td><td><span class='badge $badgeClass'>$($_.MediaType)</span></td><td>$($_.SizeGB) GB</td></tr>"
    }
    return ($rows -join "`n")
}

function New-HtmlReport {
    [OutputType([string])]
    param([Parameter(Mandatory)][ReportData]$ReportData)

    $devRows   = ConvertTo-AnalysisTableRows -Results @($ReportData.Results | Where-Object { $_.Category -eq "Development" })
    $gameRows  = ConvertTo-AnalysisTableRows -Results @($ReportData.Results | Where-Object { $_.Category -eq "Game" })
    $storageRows = ConvertTo-StorageTableRows -Devices $ReportData.Storage
    $recommendationItems = ConvertTo-RecommendationListItems -Recommendations $ReportData.Recommendations

    $excellentCount = @($ReportData.Results | Where-Object { $_.Verdict -eq [VerdictLevel]::Excellent }).Count
    $failedCount    = @($ReportData.Results | Where-Object { $_.Verdict -eq [VerdictLevel]::NotRecommended }).Count
    $hw = $ReportData.Hardware

    # Build HTML using string concatenation to avoid PowerShell parsing issues
    $html = ''

    $html += '<!DOCTYPE html>'
    $html += '<html lang="en">'
    $html += '<head>'
    $html += '<meta charset="utf-8">'
    $html += '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
    $html += '<title>PC Analyzer Report</title>'
    $html += '<style>'
    $html += ':root {'
    $html += '  --bg-deep: #0b0f19;'
    $html += '  --bg-card: #151b2b;'
    $html += '  --bg-inner: #0f1525;'
    $html += '  --border: #1e293b;'
    $html += '  --text-primary: #e2e8f0;'
    $html += '  --text-heading: #f1f5f9;'
    $html += '  --text-muted: #94a3b8;'
    $html += '  --text-dim: #64748b;'
    $html += '  --accent-blue: #60a5fa;'
    $html += '  --accent-purple: #a78bfa;'
    $html += '  --accent-cyan: #38bdf8;'
    $html += '  --accent-green: #4ade80;'
    $html += '  --accent-yellow: #facc15;'
    $html += '  --accent-red: #f87171;'
    $html += '}'
    $html += '* { box-sizing: border-box; }'
    $html += 'body {'
    $html += '  font-family: ''Segoe UI'', system-ui, -apple-system, sans-serif;'
    $html += '  background: var(--bg-deep);'
    $html += '  color: var(--text-primary);'
    $html += '  margin: 0;'
    $html += '  padding: 32px 24px;'
    $html += '  line-height: 1.5;'
    $html += '  -webkit-font-smoothing: antialiased;'
    $html += '}'
    $html += '.container { max-width: 1200px; margin: 0 auto; }'
    $html += 'header {'
    $html += '  text-align: center;'
    $html += '  margin-bottom: 32px;'
    $html += '  padding-bottom: 24px;'
    $html += '  border-bottom: 1px solid var(--border);'
    $html += '}'
    $html += 'header h1 {'
    $html += '  font-size: 2.2rem;'
    $html += '  font-weight: 700;'
    $html += '  margin: 0 0 8px 0;'
    $html += '  background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));'
    $html += '  -webkit-background-clip: text;'
    $html += '  -webkit-text-fill-color: transparent;'
    $html += '  background-clip: text;'
    $html += '}'
    $html += 'header p { color: var(--text-muted); margin: 0; font-size: 0.95rem; }'
    $html += '.score-grid {'
    $html += '  display: grid;'
    $html += '  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));'
    $html += '  gap: 20px;'
    $html += '  margin-bottom: 32px;'
    $html += '}'
    $html += '.score-card {'
    $html += '  background: var(--bg-card);'
    $html += '  border: 1px solid var(--border);'
    $html += '  border-radius: 16px;'
    $html += '  padding: 24px;'
    $html += '  text-align: center;'
    $html += '  transition: transform 0.2s, box-shadow 0.2s;'
    $html += '}'
    $html += '.score-card:hover {'
    $html += '  transform: translateY(-2px);'
    $html += '  box-shadow: 0 8px 24px rgba(0,0,0,0.3);'
    $html += '}'
    $html += '.score-icon {'
    $html += '  width: 40px;'
    $html += '  height: 40px;'
    $html += '  margin: 0 auto 12px;'
    $html += '  color: var(--text-muted);'
    $html += '}'
    $html += '.score-icon svg { width: 100%; height: 100%; }'
    $html += '.score-value {'
    $html += '  font-size: 2.5rem;'
    $html += '  font-weight: 800;'
    $html += '  margin-bottom: 4px;'
    $html += '}'
    $html += '.score-gaming .score-value { color: var(--accent-purple); }'
    $html += '.score-dev .score-value { color: var(--accent-cyan); }'
    $html += '.score-excellent .score-value { color: var(--accent-green); }'
    $html += '.score-failed .score-value { color: var(--accent-red); }'
    $html += '.score-label {'
    $html += '  color: var(--text-muted);'
    $html += '  font-size: 0.85rem;'
    $html += '  font-weight: 500;'
    $html += '  text-transform: uppercase;'
    $html += '  letter-spacing: 0.5px;'
    $html += '  margin-bottom: 12px;'
    $html += '}'
    $html += '.score-bar {'
    $html += '  width: 100%;'
    $html += '  height: 6px;'
    $html += '  background: var(--bg-inner);'
    $html += '  border-radius: 3px;'
    $html += '  overflow: hidden;'
    $html += '}'
    $html += '.score-fill {'
    $html += '  height: 100%;'
    $html += '  border-radius: 3px;'
    $html += '  transition: width 0.8s ease;'
    $html += '}'
    $html += '.card {'
    $html += '  background: var(--bg-card);'
    $html += '  border: 1px solid var(--border);'
    $html += '  border-radius: 16px;'
    $html += '  padding: 24px;'
    $html += '  margin-bottom: 24px;'
    $html += '}'
    $html += '.card-header {'
    $html += '  display: flex;'
    $html += '  align-items: center;'
    $html += '  gap: 12px;'
    $html += '  margin-bottom: 20px;'
    $html += '  padding-bottom: 16px;'
    $html += '  border-bottom: 1px solid var(--border);'
    $html += '}'
    $html += '.card-icon {'
    $html += '  width: 32px;'
    $html += '  height: 32px;'
    $html += '  color: var(--accent-blue);'
    $html += '  flex-shrink: 0;'
    $html += '}'
    $html += '.card-icon svg { width: 100%; height: 100%; }'
    $html += '.card-header h2 {'
    $html += '  margin: 0;'
    $html += '  font-size: 1.25rem;'
    $html += '  font-weight: 600;'
    $html += '  color: var(--text-heading);'
    $html += '}'
    $html += '.hardware-grid {'
    $html += '  display: grid;'
    $html += '  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));'
    $html += '  gap: 16px;'
    $html += '}'
    $html += '.hardware-item {'
    $html += '  display: flex;'
    $html += '  align-items: flex-start;'
    $html += '  gap: 14px;'
    $html += '  background: var(--bg-inner);'
    $html += '  border: 1px solid var(--border);'
    $html += '  border-radius: 12px;'
    $html += '  padding: 16px;'
    $html += '}'
    $html += '.hardware-icon {'
    $html += '  width: 36px;'
    $html += '  height: 36px;'
    $html += '  border-radius: 10px;'
    $html += '  display: flex;'
    $html += '  align-items: center;'
    $html += '  justify-content: center;'
    $html += '  flex-shrink: 0;'
    $html += '}'
    $html += '.hardware-icon svg { width: 20px; height: 20px; }'
    $html += '.icon-cpu { background: rgba(96, 165, 250, 0.15); color: var(--accent-blue); }'
    $html += '.icon-ram { background: rgba(167, 139, 250, 0.15); color: var(--accent-purple); }'
    $html += '.icon-gpu { background: rgba(56, 189, 248, 0.15); color: var(--accent-cyan); }'
    $html += '.icon-os  { background: rgba(74, 222, 128, 0.15); color: var(--accent-green); }'
    $html += '.hw-label {'
    $html += '  font-size: 0.75rem;'
    $html += '  text-transform: uppercase;'
    $html += '  letter-spacing: 0.5px;'
    $html += '  color: var(--text-muted);'
    $html += '  margin-bottom: 4px;'
    $html += '  font-weight: 600;'
    $html += '}'
    $html += '.hw-value {'
    $html += '  font-size: 1rem;'
    $html += '  font-weight: 600;'
    $html += '  color: var(--text-heading);'
    $html += '  margin-bottom: 2px;'
    $html += '}'
    $html += '.hw-meta { font-size: 0.8rem; color: var(--text-dim); }'
    $html += '.table-wrap { overflow-x: auto; }'
    $html += 'table {'
    $html += '  width: 100%;'
    $html += '  border-collapse: separate;'
    $html += '  border-spacing: 0;'
    $html += '  font-size: 0.9rem;'
    $html += '}'
    $html += 'th {'
    $html += '  background: var(--bg-inner);'
    $html += '  color: var(--text-muted);'
    $html += '  padding: 12px 16px;'
    $html += '  text-align: left;'
    $html += '  font-weight: 600;'
    $html += '  font-size: 0.8rem;'
    $html += '  text-transform: uppercase;'
    $html += '  letter-spacing: 0.5px;'
    $html += '  border-bottom: 2px solid var(--border);'
    $html += '  position: sticky;'
    $html += '  top: 0;'
    $html += '}'
    $html += 'td {'
    $html += '  padding: 14px 16px;'
    $html += '  border-bottom: 1px solid var(--border);'
    $html += '  vertical-align: middle;'
    $html += '}'
    $html += 'tbody tr:hover { background: var(--bg-inner); }'
    $html += '.row-good { background: rgba(74, 222, 128, 0.04); }'
    $html += '.row-warn { background: rgba(250, 204, 21, 0.04); }'
    $html += '.row-bad  { background: rgba(248, 113, 113, 0.04); }'
    $html += '.cell-flex {'
    $html += '  display: flex;'
    $html += '  align-items: center;'
    $html += '  gap: 10px;'
    $html += '}'
    $html += '.dot {'
    $html += '  width: 8px;'
    $html += '  height: 8px;'
    $html += '  border-radius: 50%;'
    $html += '  flex-shrink: 0;'
    $html += '}'
    $html += '.dot-ssd { background: var(--accent-green); box-shadow: 0 0 6px rgba(74, 222, 128, 0.4); }'
    $html += '.dot-hdd { background: var(--accent-red); box-shadow: 0 0 6px rgba(248, 113, 113, 0.4); }'
    $html += '.badge {'
    $html += '  display: inline-block;'
    $html += '  padding: 3px 10px;'
    $html += '  border-radius: 20px;'
    $html += '  font-size: 0.75rem;'
    $html += '  font-weight: 600;'
    $html += '  text-transform: uppercase;'
    $html += '  letter-spacing: 0.3px;'
    $html += '}'
    $html += '.badge-ssd { background: rgba(74, 222, 128, 0.15); color: var(--accent-green); }'
    $html += '.badge-hdd { background: rgba(248, 113, 113, 0.15); color: var(--accent-red); }'
    $html += '.status {'
    $html += '  display: inline-block;'
    $html += '  padding: 4px 10px;'
    $html += '  border-radius: 6px;'
    $html += '  font-size: 0.8rem;'
    $html += '  font-weight: 500;'
    $html += '}'
    $html += '.status-rec { background: rgba(74, 222, 128, 0.12); color: var(--accent-green); }'
    $html += '.status-min { background: rgba(250, 204, 21, 0.12); color: var(--accent-yellow); }'
    $html += '.status-below { background: rgba(248, 113, 113, 0.12); color: var(--accent-red); }'
    $html += '.verdict {'
    $html += '  display: inline-block;'
    $html += '  padding: 4px 12px;'
    $html += '  border-radius: 20px;'
    $html += '  font-size: 0.8rem;'
    $html += '  font-weight: 600;'
    $html += '}'
    $html += '.verdict-excellent { background: rgba(74, 222, 128, 0.15); color: var(--accent-green); }'
    $html += '.verdict-playable { background: rgba(250, 204, 21, 0.15); color: var(--accent-yellow); }'
    $html += '.verdict-bad { background: rgba(248, 113, 113, 0.15); color: var(--accent-red); }'
    $html += '.progress {'
    $html += '  width: 100%;'
    $html += '  height: 22px;'
    $html += '  background: var(--bg-inner);'
    $html += '  border-radius: 11px;'
    $html += '  overflow: hidden;'
    $html += '  border: 1px solid var(--border);'
    $html += '}'
    $html += '.progress-fill {'
    $html += '  height: 100%;'
    $html += '  color: white;'
    $html += '  text-align: center;'
    $html += '  line-height: 22px;'
    $html += '  font-size: 0.75rem;'
    $html += '  font-weight: 700;'
    $html += '  transition: width 0.8s ease;'
    $html += '}'
    $html += '.recommendations {'
    $html += '  list-style: none;'
    $html += '  padding: 0;'
    $html += '  margin: 0;'
    $html += '}'
    $html += '.recommendations li {'
    $html += '  display: flex;'
    $html += '  align-items: center;'
    $html += '  gap: 12px;'
    $html += '  padding: 12px 16px;'
    $html += '  background: var(--bg-inner);'
    $html += '  border: 1px solid var(--border);'
    $html += '  border-radius: 10px;'
    $html += '  margin-bottom: 10px;'
    $html += '  font-size: 0.95rem;'
    $html += '}'
    $html += '.rec-icon {'
    $html += '  width: 24px;'
    $html += '  height: 24px;'
    $html += '  border-radius: 50%;'
    $html += '  background: rgba(74, 222, 128, 0.15);'
    $html += '  color: var(--accent-green);'
    $html += '  display: flex;'
    $html += '  align-items: center;'
    $html += '  justify-content: center;'
    $html += '  font-size: 0.8rem;'
    $html += '  flex-shrink: 0;'
    $html += '}'
    $html += 'footer {'
    $html += '  text-align: center;'
    $html += '  color: #475569;'
    $html += '  font-size: 0.8rem;'
    $html += '  margin-top: 16px;'
    $html += '  padding-top: 24px;'
    $html += '  border-top: 1px solid var(--border);'
    $html += '}'
    $html += '@media (max-width: 768px) {'
    $html += '  body { padding: 16px; }'
    $html += '  .score-grid { grid-template-columns: repeat(2, 1fr); }'
    $html += '  header h1 { font-size: 1.6rem; }'
    $html += '  .score-value { font-size: 1.8rem; }'
    $html += '  .hardware-grid { grid-template-columns: 1fr; }'
    $html += '  th, td { padding: 10px 12px; font-size: 0.8rem; }'
    $html += '}'
    $html += '@media (max-width: 480px) {'
    $html += '  .score-grid { grid-template-columns: 1fr; }'
    $html += '}'
    $html += '</style>'
    $html += '</head>'
    $html += '<body>'
    $html += '<div class="container">'

    $html += '<header>'
    $html += '  <h1>PC Analyzer Report</h1>'
    $html += '  <p>Hardware Capability Assessment Dashboard</p>'
    $html += '</header>'

    $html += '<div class="score-grid">'
    $html += '  <div class="score-card score-gaming">'
    $html += '    <div class="score-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 11h4M8 9v4M15 12h.01M18 10h.01M17 16h.01M12 16h.01M7 16h.01M2 12h20a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2z"></path><path d="M2 12v4a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-4"></path></svg>'
    $html += '    </div>'
    $html += '    <div class="score-value">' + $ReportData.GamingScore + '</div>'
    $html += '    <div class="score-label">Gaming Score</div>'
    $html += '    <div class="score-bar"><div class="score-fill" style="width:' + $ReportData.GamingScore + '%;background:var(--accent-purple)"></div></div>'
    $html += '  </div>'
    $html += '  <div class="score-card score-dev">'
    $html += '    <div class="score-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>'
    $html += '    </div>'
    $html += '    <div class="score-value">' + $ReportData.DevelopmentScore + '</div>'
    $html += '    <div class="score-label">Development Score</div>'
    $html += '    <div class="score-bar"><div class="score-fill" style="width:' + $ReportData.DevelopmentScore + '%;background:var(--accent-cyan)"></div></div>'
    $html += '  </div>'
    $html += '  <div class="score-card score-excellent">'
    $html += '    <div class="score-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>'
    $html += '    </div>'
    $html += '    <div class="score-value">' + $excellentCount + '</div>'
    $html += '    <div class="score-label">Excellent</div>'
    $html += '    <div class="score-bar"><div class="score-fill" style="width:100%;background:var(--accent-green)"></div></div>'
    $html += '  </div>'
    $html += '  <div class="score-card score-failed">'
    $html += '    <div class="score-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>'
    $html += '    </div>'
    $html += '    <div class="score-value">' + $failedCount + '</div>'
    $html += '    <div class="score-label">Needs Work</div>'
    $html += '    <div class="score-bar"><div class="score-fill" style="width:40%;background:var(--accent-red)"></div></div>'
    $html += '  </div>'
    $html += '</div>'

    $html += '<div class="card">'
    $html += '  <div class="card-header">'
    $html += '    <div class="card-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect><rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect><line x1="6" y1="6" x2="6.01" y2="6"></line><line x1="6" y1="18" x2="6.01" y2="18"></line></svg>'
    $html += '    </div>'
    $html += '    <h2>Detected Hardware</h2>'
    $html += '  </div>'
    $html += '  <div class="hardware-grid">'
    $html += '    <div class="hardware-item">'
    $html += '      <div class="hardware-icon icon-cpu">'
    $html += '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="2" ry="2"></rect><rect x="9" y="9" width="6" height="6"></rect><line x1="9" y1="1" x2="9" y2="4"></line><line x1="15" y1="1" x2="15" y2="4"></line><line x1="9" y1="20" x2="9" y2="23"></line><line x1="15" y1="20" x2="15" y2="23"></line><line x1="20" y1="9" x2="23" y2="9"></line><line x1="20" y1="14" x2="23" y2="14"></line><line x1="1" y1="9" x2="4" y2="9"></line><line x1="1" y1="14" x2="4" y2="14"></line></svg>'
    $html += '      </div>'
    $html += '      <div>'
    $html += '        <div class="hw-label">CPU Core</div>'
    $html += '        <div class="hw-value">' + $hw.CpuName + '</div>'
    $html += '        <div class="hw-meta">' + $hw.CpuCores + ' Cores / ' + $hw.CpuThreads + ' Threads @ ' + $hw.CpuClockGHz + ' GHz</div>'
    $html += '      </div>'
    $html += '    </div>'
    $html += '    <div class="hardware-item">'
    $html += '      <div class="hardware-icon icon-ram">'
    $html += '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"></path><path d="M20 12v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-6"></path><path d="M12 12V4"></path><path d="M12 4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v8"></path><path d="M4 12a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v8"></path></svg>'
    $html += '      </div>'
    $html += '      <div>'
    $html += '        <div class="hw-label">RAM</div>'
    $html += '        <div class="hw-value">' + $hw.RamGB + ' GB</div>'
    $html += '        <div class="hw-meta">Total Physical Memory</div>'
    $html += '      </div>'
    $html += '    </div>'
    $html += '    <div class="hardware-item">'
    $html += '      <div class="hardware-icon icon-gpu">'
    $html += '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 12V7.5a2.5 2.5 0 0 0-5 0V12"></path><path d="M14 12H9"></path><path d="M9 12v5.5a2.5 2.5 0 0 0 5 0V12"></path><path d="M14 12H19"></path><path d="M19 12v-5.5a2.5 2.5 0 0 0-5 0V12"></path><path d="M19 12v5.5a2.5 2.5 0 0 0 5 0V12"></path><path d="M19 12H24"></path></svg>'
    $html += '      </div>'
    $html += '      <div>'
    $html += '        <div class="hw-label">GPU</div>'
    $html += '        <div class="hw-value">' + $hw.GpuName + '</div>'
    $html += '        <div class="hw-meta">' + $hw.GpuVramGB + ' GB VRAM</div>'
    $html += '      </div>'
    $html += '    </div>'
    $html += '    <div class="hardware-item">'
    $html += '      <div class="hardware-icon icon-os">'
    $html += '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>'
    $html += '      </div>'
    $html += '      <div>'
    $html += '        <div class="hw-label">OS</div>'
    $html += '        <div class="hw-value">' + $hw.WindowsVersion + '</div>'
    $html += '        <div class="hw-meta">Operating System</div>'
    $html += '      </div>'
    $html += '    </div>'
    $html += '  </div>'
    $html += '</div>'

    $html += '<div class="card">'
    $html += '  <div class="card-header">'
    $html += '    <div class="card-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>'
    $html += '    </div>'
    $html += '    <h2>Storage Devices</h2>'
    $html += '  </div>'
    $html += '  <div class="table-wrap">'
    $html += '    <table>'
    $html += '      <thead>'
    $html += '        <tr><th>Drive</th><th>Type</th><th>Size</th></tr>'
    $html += '      </thead>'
    $html += '      <tbody>'
    $html += '        ' + $storageRows
    $html += '      </tbody>'
    $html += '    </table>'
    $html += '  </div>'
    $html += '</div>'

    $html += '<div class="card">'
    $html += '  <div class="card-header">'
    $html += '    <div class="card-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>'
    $html += '    </div>'
    $html += '    <h2>Development Software Analysis</h2>'
    $html += '  </div>'
    $html += '  <div class="table-wrap">'
    $html += '    <table>'
    $html += '      <thead>'
    $html += '        <tr><th>Software</th><th>RAM</th><th>CPU Cores</th><th>GPU</th><th>Verdict</th><th>Score</th></tr>'
    $html += '      </thead>'
    $html += '      <tbody>'
    $html += '        ' + $devRows
    $html += '      </tbody>'
    $html += '    </table>'
    $html += '  </div>'
    $html += '</div>'

    $html += '<div class="card">'
    $html += '  <div class="card-header">'
    $html += '    <div class="card-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 11h4M8 9v4M15 12h.01M18 10h.01M17 16h.01M12 16h.01M7 16h.01M2 12h20a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2z"></path><path d="M2 12v4a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-4"></path></svg>'
    $html += '    </div>'
    $html += '    <h2>Game Analysis</h2>'
    $html += '  </div>'
    $html += '  <div class="table-wrap">'
    $html += '    <table>'
    $html += '      <thead>'
    $html += '        <tr><th>Game</th><th>RAM</th><th>CPU Cores</th><th>GPU</th><th>Verdict</th><th>Score</th></tr>'
    $html += '      </thead>'
    $html += '      <tbody>'
    $html += '        ' + $gameRows
    $html += '      </tbody>'
    $html += '    </table>'
    $html += '  </div>'
    $html += '</div>'

    $html += '<div class="card">'
    $html += '  <div class="card-header">'
    $html += '    <div class="card-icon">'
    $html += '      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>'
    $html += '    </div>'
    $html += '    <h2>Upgrade Recommendations</h2>'
    $html += '  </div>'
    $html += '  <ul class="recommendations">'
    $html += '    ' + $recommendationItems
    $html += '  </ul>'
    $html += '</div>'

    $html += '<footer>'
    $html += '  Generated by Hashim Hussain - PC Analyzer'
    $html += '</footer>'

    $html += '</div>'
    $html += '</body>'
    $html += '</html>'

    return $html
}

function Save-Report {
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -Path $directory)) {
        try {
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
        }
        catch {
            throw [System.IO.DirectoryNotFoundException]::new(
                "Output directory '$directory' does not exist and could not be created.", $_.Exception)
        }
    }

    try {
        $Html | Set-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
    }
    catch [System.UnauthorizedAccessException] {
        throw [System.UnauthorizedAccessException]::new(
            "Access denied writing report to '$Path'. Try running as Administrator or choose a different -OutputPath.", $_.Exception)
    }
    catch {
        throw [System.IO.IOException]::new("Failed to write report to '$Path': $($_.Exception.Message)", $_.Exception)
    }
}

function Write-AnalysisSummary {
    param([Parameter(Mandatory)][ReportData]$ReportData)

    Write-Host ""
    Write-Host "Hardware Analysis Complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "Gaming Score      : $($ReportData.GamingScore)"
    Write-Host "Development Score : $($ReportData.DevelopmentScore)"
    Write-Host ""
}

# ==========================================================
# ORCHESTRATION
# ==========================================================

function Invoke-PCAnalyzer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutputPath
    )

    try {
        Write-Host "Scanning hardware..." -ForegroundColor Cyan

        $hardware = Get-HardwareProfile
        $storage  = Get-StorageDevices
        $catalog  = Get-SoftwareCatalog
        $results  = Invoke-CatalogAnalysis -Hardware $hardware -Catalog $catalog

        $reportData = [ReportData]@{
            Hardware         = $hardware
            Storage          = $storage
            Results          = $results
            GamingScore      = Get-CategoryScore -Results $results -Category "Game"
            DevelopmentScore = Get-CategoryScore -Results $results -Category "Development"
            Recommendations  = Get-UpgradeRecommendations -Hardware $hardware -Storage $storage
        }

        Write-AnalysisSummary -ReportData $reportData

        $html = New-HtmlReport -ReportData $reportData
        Save-Report -Html $html -Path $OutputPath

        Write-Host ""
        Write-Host "====================================" -ForegroundColor Green
        Write-Host "REPORT GENERATED" -ForegroundColor Green
        Write-Host "====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host $OutputPath -ForegroundColor Cyan
        Write-Host ""

        Start-Process $OutputPath
    }
    catch {
        Write-Error "PC Analyzer failed: $($_.Exception.Message)"
        exit 1
    }
}

Invoke-PCAnalyzer -OutputPath $OutputPath