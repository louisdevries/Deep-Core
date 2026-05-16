# Drilling Game (Prototype)

A 2D top-down underground mining game built in Godot 4 using TileMapLayer systems.

The player drills through procedurally generated terrain while navigating fog of war, light-based visibility, and exploration tools like sonar. Built for mobile.

---

## 🧱 Core Systems

### 🌍 Terrain Generation
- Procedural tile-based world using TileMapLayer
- Multiple depth layers (dirt, stone, deep stone, ores)
- Randomized cave zones with ore distribution

---

### 🌫️ Fog of War System
- Entire map is initially covered in fog
- Fog is dynamically removed based on player visibility
- Fog reappears outside of light radius (real-time system)

---

### 🔦 Light-Based Visibility
- Player has a PointLight2D-based visibility radius
- Line-of-sight system prevents seeing through solid tiles
- Visibility is calculated in tile space (not screen space)

---

### 📡 Sonar System
- Active ability that reveals terrain in a radius
- Temporarily removes fog regardless of lighting
- Designed for exploration and scouting underground areas

---

### ⛏️ Drilling System
- Tile-based destruction system
- Gear and power affect break strength
- Resource collection from destroyed tiles (ore types)

---

### 💰 Resources & Upgrades
- Copper, iron, crystal resource tracking
- Drill power upgrades with material + money requirements
- Cargo system limits resource collection

---

## ⚙️ Technical Notes

- Built using Godot 4 TileMapLayer system
- Uses coordinate conversion between world space and tile space
- Fog system is separate from terrain rendering layer
- Light system is logic-driven (not purely visual shaders)

---

## 🚧 Current Focus

- Stabilizing fog + visibility consistency
- Improving light blocking accuracy in caves
- Expanding sonar functionality
- Preparing upgrade and progression systems

---

## 📌 Known Design Direction

The game is evolving toward:
- Terraria-style underground exploration
- Fog-of-war + scanner gameplay loop
- System-driven procedural mining rather than handcrafted levels
