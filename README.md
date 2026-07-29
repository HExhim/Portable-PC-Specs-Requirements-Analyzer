# PC Analyzer 💻📊

A portable Windows utility that analyzes your computer's hardware, evaluates its ability to run popular software and games, and generates a modern HTML report with compatibility results, performance scores, and hardware upgrade recommendations.

The application works completely offline and requires no installation or additional dependencies.

---

## Features

* Portable executable (`PCAnalyzer.exe`)
* No installation required
* Automatic CPU, RAM, GPU, Storage, and OS detection
* SSD/HDD identification
* Gaming compatibility analysis
* Development software compatibility analysis
* Gaming and Development performance scores
* Intelligent hardware upgrade recommendations
* Dark-themed interactive HTML report
* Zero-dependency HTML output
* Works completely offline

---

## Supported Software

### Development

* Android Studio
* Unity 2022
* Blender
* Visual Studio

### Games

* GTA V
* Tekken 7
* Forza Horizon 5
* PUBG Mobile Emulator

The catalog can be expanded by editing a single configuration function inside the project.

---

## Quick Start

### Option 1 — Portable Executable (Recommended)

1. Download **PCAnalyzer.exe** from the latest Release.
2. Double-click the executable.
3. Wait for hardware detection to finish.
4. Your HTML report opens automatically in the default browser.

---

### Option 2 — Batch Launcher

Run:

```text
RunAnalyzer.bat
```

This temporarily bypasses the PowerShell execution policy and launches the analyzer.

---

### Option 3 — PowerShell

Clone the repository:

```bash
git clone https://github.com/HExhim/Portable-PC-Specs-Requirements-Analyzer.git

cd Portable-PC-Specs-Requirements-Analyzer
```

(Optional)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

Run:

```powershell
.\PCAnalyzer.ps1
```

Generate the report at a custom location:

```powershell
.\PCAnalyzer.ps1 -OutputPath "C:\Reports\MyPCReport.html"
```

---

## Generated Report

After the scan completes, the analyzer automatically generates a self-contained HTML report that includes:

* System specifications
* CPU information
* Memory information
* GPU information
* Storage information
* Operating system details
* Gaming score
* Development score
* Compatibility results
* Upgrade recommendations

The report is automatically opened in your default web browser.

---

## How It Works

```
Launch
   │
   ▼
Hardware Detection
   │
   ▼
System Analysis
   │
   ▼
Requirement Comparison
   │
   ▼
Performance Scoring
   │
   ▼
HTML Report Generation
   │
   ▼
Open Report
```

---

## Customizing the Software Catalog

Applications and games are defined inside the `Get-SoftwareCatalog` function.

Example:

```powershell
@{
    Name     = "Custom App"
    Category = "Development"   # Development or Game

    MinRAM   = 8
    RecRAM   = 16

    MinCPU   = 4
    RecCPU   = 8

    MinVRAM  = 2
    RecVRAM  = 4
}
```

Simply add additional entries to extend the compatibility database.

---

## Project Structure

```text
PCAnalyzer/
│
├── PCAnalyzer.ps1
├── RunAnalyzer.bat
├── README.md
└── LICENSE

```

---

## Technologies Used

* PowerShell
* WMI / CIM
* Windows Forms
* HTML5
* CSS3
* JavaScript

---

## Roadmap

* More games
* More development software
* CPU benchmark database
* GPU benchmark database
* Export to PDF
* System health monitoring
* Driver version detection
* Internet-based requirement updates
* Automatic software catalog updates

---

## License

This project is currently unlicensed.

See the `LICENSE` file for details.
