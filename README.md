# PC Analyzer 💻📊

<p align="center">
  <strong>Portable Windows Hardware & Compatibility Analyzer</strong>
  <br>
  Analyze your PC, evaluate software & game compatibility, calculate performance scores, and get actionable hardware upgrade recommendations — completely offline.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/Offline-100%25-2EA44F?style=for-the-badge" alt="Offline">
  <img src="https://img.shields.io/badge/Portable-No%20Install-8250DF?style=for-the-badge" alt="Portable">
</p>

<p align="center">
  <a href="#overview">Overview</a>
  &nbsp;•&nbsp;
  <a href="#features">Features</a>
  &nbsp;•&nbsp;
  <a href="#screenshots">Screenshots</a>
  &nbsp;•&nbsp;
  <a href="#supported-software">Supported Software</a>
  &nbsp;•&nbsp;
  <a href="#quick-start">Quick Start</a>
  &nbsp;•&nbsp;
  <a href="#generated-report">Generated Report</a>
  &nbsp;•&nbsp;
  <a href="#roadmap">Roadmap</a>
</p>

---

##  Overview

**PC Analyzer** is a portable Windows utility that automatically analyzes your computer hardware and determines how well your system can handle popular development tools and games.

It detects your:

* CPU
* RAM
* GPU
* VRAM
* Storage
* SSD / HDD configuration
* Windows version

It then compares your hardware against configurable minimum and recommended requirements and generates a modern, self-contained HTML report.

> **No installation. No internet connection. No external dependencies.**

---

##  Features

| Feature                     | Description                                               |
| --------------------------- | --------------------------------------------------------- |
| 🖥️ Hardware Detection      | Automatically detects CPU, RAM, GPU, VRAM, storage and OS |
| 💾 Storage Analysis         | Identifies SSD and HDD storage                            |
| 🎮 Game Compatibility       | Evaluates whether your PC can run supported games         |
| 🛠️ Developer Compatibility | Checks development software requirements                  |
| 📊 Performance Scores       | Generates separate Gaming and Development scores          |
| 🔧 Upgrade Recommendations  | Identifies hardware components that may need upgrading    |
| 🌐 HTML Reports             | Generates a modern interactive report                     |
| 📦 Portable                 | Run directly without installation                         |
| 🔒 Offline                  | No internet connection required                           |
| ⚡ Zero Dependencies         | Generated reports require no external libraries           |

---

##  Screenshots

<p align="center">
  <img src="Images/Screenshot%202026-07-29%20023102.png" width="100%" alt="PC Analyzer Screenshot 1">
  <img src="Images/Screenshot%202026-07-29%20023142.png" width="100%" alt="PC Analyzer Screenshot 2">
  <img src="Images/Screenshot%202026-07-29%20023218.png" width="100%" alt="PC Analyzer Screenshot 3">
</p>

<p align="center">
  <sub>PC Analyzer generated reports and compatibility analysis</sub>
</p>

---

##  Supported Software

### 🛠️ Development

| Software       | Category             |
| -------------- | -------------------- |
| Android Studio | Android Development  |
| Unity 2022     | Game Development     |
| Blender        | 3D / Rendering       |
| Visual Studio  | Software Development |

### 🎮 Games

| Game                 | Category   |
| -------------------- | ---------- |
| GTA V                | Open World |
| Tekken 7             | Fighting   |
| Forza Horizon 5      | Racing     |
| PUBG Mobile Emulator | Emulator   |

The software catalog is configurable and can be expanded by modifying a single configuration function inside the project.

---

##  Quick Start

### Option 1 — Portable Executable

**Recommended for normal users.**

1. Download `PCAnalyzer.exe` from the latest GitHub Release.
2. Double-click the executable.
3. Wait for the hardware scan to complete.
4. The generated HTML report opens automatically in your default browser.

No installation is required.

---

### Option 2 — Batch Launcher

Run:

```text
RunAnalyzer.bat
```

The launcher temporarily bypasses the PowerShell execution policy and starts the analyzer.

---

### Option 3 — PowerShell

Clone the repository:

```bash
git clone https://github.com/HExhim/Portable-PC-Specs-Requirements-Analyzer.git

cd Portable-PC-Specs-Requirements-Analyzer
```

Run the analyzer:

```powershell
.\PCAnalyzer.ps1
```

If required, temporarily allow PowerShell scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

Generate the report at a custom location:

```powershell
.\PCAnalyzer.ps1 -OutputPath "C:\Reports\MyPCReport.html"
```

---

##  Generated Report

After the scan completes, PC Analyzer generates a self-contained HTML report containing:

* 🖥️ System specifications
* ⚙️ CPU information
* 🧠 Memory information
* 🎮 GPU information
* 💾 Storage information
* 🪟 Operating system details
* 🎮 Gaming performance score
* 🛠️ Development performance score
* ✅ Compatibility results
* ⚠️ Hardware limitations
* 🔧 Upgrade recommendations

The report automatically opens in your default web browser.

---

##  How Compatibility Analysis Works

PC Analyzer compares detected hardware against configurable minimum and recommended requirements.

For example:

```powershell
@{
    Name     = "Custom App"
    Category = "Development"

    MinRAM   = 8
    RecRAM   = 16

    MinCPU   = 4
    RecCPU   = 8

    MinVRAM  = 2
    RecVRAM  = 4
}
```

The analyzer evaluates the detected hardware and produces a compatibility result based on the defined requirements.

This makes the catalog easy to extend without modifying the core analysis logic.

---

##  Customizing the Software Catalog

Applications and games are defined inside the:

```text
Get-SoftwareCatalog
```

function.

To add a new application, create another configuration entry using the same structure:

```powershell
@{
    Name     = "Custom App"
    Category = "Development"

    MinRAM   = 8
    RecRAM   = 16

    MinCPU   = 4
    RecCPU   = 8

    MinVRAM  = 2
    RecVRAM  = 4
}
```

You can add additional games and development applications without changing the main analyzer workflow.

---

##  Project Structure

```text
PCAnalyzer/
│
├── PCAnalyzer.ps1       # Main analyzer
├── RunAnalyzer.bat      # Batch launcher
├── README.md            # Documentation
└── LICENSE              # License information
```

---

##  Technologies

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/WMI%20%2F%20CIM-0078D6?style=flat-square" alt="WMI/CIM">
  <img src="https://img.shields.io/badge/Windows%20Forms-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows Forms">
  <img src="https://img.shields.io/badge/HTML5-E34F26?style=flat-square&logo=html5&logoColor=white" alt="HTML5">
  <img src="https://img.shields.io/badge/CSS3-1572B6?style=flat-square&logo=css3&logoColor=white" alt="CSS3">
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=flat-square&logo=javascript&logoColor=black" alt="JavaScript">
</p>

---

##  Roadmap

* [ ] Expand supported game catalog
* [ ] Expand development software catalog
* [ ] CPU benchmark database
* [ ] GPU benchmark database
* [ ] PDF report export
* [ ] System health monitoring
* [ ] Driver version detection
* [ ] Internet-based hardware requirement updates
* [ ] Automatic software catalog updates
* [ ] Historical performance tracking
* [ ] Hardware bottleneck analysis

---

## 🤝 Contributing

Contributions are welcome.

You can contribute by:

* Adding new software requirements
* Adding new games
* Improving hardware detection
* Improving compatibility calculations
* Improving the generated report
* Fixing bugs
* Improving documentation

Fork the repository, make your changes, and submit a pull request.

---

## 📄 License

This project is currently unlicensed.

See the [`LICENSE`](LICENSE) file for the applicable license information.

---

<p align="center">
  <strong>PC Analyzer</strong>
  <br>
  <sub>Know your hardware. Understand your limits. Upgrade intelligently.</sub>
</p>
