# ✈️ SKYtech vehiKits

Welcome to the official repository for **SKYtech vehiKits**. This repository houses our complete vehicle asset framework, serving as the central hub for version control, collaborative development, and deployment tracking across cloud and production environments.

By tracking our production-ready assets here in structured plain-text Luau files, we maintain a clean history of our flight mechanics and physics code, allowing for seamless updates, collaborative Git workflows, and version rollbacks.

---

## 🚀 Active Kits

This repository actively manages the source files for our core flight packages:
*   🛩️ **aeroMini** – Ultra-compact flight mechanics variant optimized for smaller frames.
*   🛸 **aeroLite** – Standard lightweight aerodynamic flight package.
*   🚁 **rotorLite** – Lightweight variant optimized for agile rotary-wing performance.

---

## 🛠️ WIP Kits

These kits are currently under active development and testing. They are yet to be released and may receive frequent physics tuning and structural changes:
*   🛩️ **aeroKit** – Advanced, full-scale aerodynamic flight physics framework.
*   🚁 **rotorKit** – Standard helicopter/rotary-wing physics engine framework.
*   🚗 **autoKit** – Advanced ground vehicle physics and custom chassis framework.

---

## 📂 Repository Structure

Each kit directory is organized as follows:
```text
[KitName]/
├── Source Codes/
│   └── MainModule/
│       ├── ReplicatedStorage/    # Client-side scripts and modules
│       ├── ServerScriptService/  # Server-side scripts, master modules, and packages
│       └── init.luau             # Main kit initialization entry point
├── [KitName] (Cloud Version).rbxm
└── [KitName] (Non-cloud Version).rbxm
```

---

## 🛠️ How to Use These Assets

### Option A: Syncing Source Files (Recommended for Development)
We maintain the source code in structured directories matching the Roblox Service structure (`ReplicatedStorage` and `ServerScriptService`):
1. Navigate to the kit's `Source Codes/MainModule` folder.
2. Edit or sync the scripts to your Roblox Studio workspace (e.g., using **Rojo** or file-syncing utilities).
3. The `init.luau` script handles placing and enabling packages in the correct services automatically at game runtime.

### Option B: Pre-packaged Models
For quick deployment, you can import pre-packaged Roblox model files:
1. Navigate to the directory of the kit you need.
2. Download the `.rbxm` file:
   * **Cloud Version:** Ideal for setups utilizing cloud database integration.
   * **Non-cloud Version:** Standalone variant.
3. **Drag and drop** the file directly from your local file explorer into your Roblox Studio **Explorer** window (or right-click an empty space in the Explorer, select **Insert from File...**, and open the asset).
