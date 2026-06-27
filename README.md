# SKYtech vehiKits

Welcome to the official repository for **SKYtech vehiKits**. This repository houses our complete vehicle asset framework, serving as the central hub for version control, collaborative development, and deployment tracking across cloud and production environments.

By tracking our production-ready assets here in plain-text XML format, we maintain a clean history of our physics code, allowing for seamless updates, bug tracking, and version rollbacks.

---

## 📂 Repository Structure

The workspace is organized to separate active development assets from historical and production-ready deployments:

*   **`Developer Versions/`** – Contains our active production flight and vehicle packages saved in `.rbxmx` (XML text) format. This is the primary directory for Git version tracking.
*   **`Cloud Releases/`** – Stable, packaged assets formatted and configured specifically for cloud-synchronized test environments and live server production.
*   **`Non-cloud Releases/`** – Standalone local framework backups and historical archive modules.

---

## 🚀 Active Kits

This repository actively manages the source files for our core flight packages:
*   🛸 **aeroLite** – Standard lightweight aerodynamic flight package.
*   🛩️ **aeroMini** – Ultra-compact flight mechanics variant optimized for smaller frames.
*   🚁 **rotorKit** – Standard helicopter/rotary-wing physics engine framework.
*   🚁 **rotorLite** – Lightweight variant optimized for agile rotary-wing performance.

---

## 🛠️ How to Use These Assets

### For Development & Tracking
All core assets in `Developer Versions` are stored as **`.rbxmx` (Roblox XML Model)** files. Unlike standard binary files, these are fully human-readable plain text, allowing GitHub to accurately diff and log every line-by-line script change we make.

### Importing Into Roblox Studio
You can import any kit from this repository directly into your Roblox Studio workspace on both Windows and macOS:
1.  Navigate to the directory of the kit you need.
2.  Download the `.rbxmx` file.
3.  **Drag and drop** the file directly from your local file explorer into your Roblox Studio **Explorer** window (or right-click an empty space in the Explorer, select **Insert from File...**, and open the asset).

---

## 💻 Contribution Workflow

When updating modules or adjusting physics behavior within Roblox Studio, follow this sequence to overwrite and commit changes safely:

1. Overwrite the updated file via Studio using **Save to File...** and choosing the `.rbxmx` format.
2. Open your terminal in the repository root and run:

```bash
git add .
git commit -m "Detail your physics, tuning, or script modifications here"
git push
