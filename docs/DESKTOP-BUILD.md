# Meow Meow Desktop App Build Guide

Build native desktop applications for **Windows**, **Linux**, and **macOS**.

## Supported Platforms

| Platform | Output Formats |
|----------|---------------|
| Windows  | `.exe` installer, Portable `.exe` |
| Linux    | `.AppImage`, `.deb`, `.rpm` |
| macOS    | `.dmg` (requires Mac to build) |

## Prerequisites

1. **Node.js** (v18 or higher)
2. **Git**
3. **Export project to GitHub** from Lovable

## Setup Instructions

### 1. Clone and Install

```bash
# Clone your repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO

# Install dependencies
npm install

# Install Electron dependencies
npm install --save-dev electron electron-builder concurrently wait-on
```

### 2. Update package.json

Add these scripts to your `package.json`:

```json
{
  "main": "electron/main.js",
  "scripts": {
    "electron:dev": "concurrently \"npm run dev\" \"wait-on http://localhost:5173 && electron .\"",
    "electron:build": "npm run build && electron-builder",
    "electron:build:win": "npm run build && electron-builder --win",
    "electron:build:linux": "npm run build && electron-builder --linux",
    "electron:build:mac": "npm run build && electron-builder --mac",
    "electron:build:mac": "npm run build && electron-builder --mac"
  }
}
```

### 3. Development Mode

Run the app in development mode:

```bash
npm run electron:dev
```

### 4. Build for Production

#### Windows (.exe installer + portable)
```bash
npm run electron:build:win
```

Output files in `release/` folder:
- `Meow Meow-x.x.x-win-x64.exe` (Installer)
- `Meow Meow-x.x.x-win-x64-portable.exe` (Portable)

#### Linux (.AppImage, .deb, .rpm)
```bash
npm run electron:build:linux
```

Output files:
- `Meow Meow-x.x.x-linux-x64.AppImage`
- `Meow Meow-x.x.x-linux-x64.deb`
- `Meow Meow-x.x.x-linux-x64.rpm`

#### macOS (.dmg)
```bash
npm run electron:build:mac
```

Output files:
- `Meow Meow-x.x.x-mac-x64.dmg` (Intel Macs)
- `Meow Meow-x.x.x-mac-arm64.dmg` (Apple Silicon M1/M2/M3)

> **Note:** Building for macOS requires a Mac computer with Xcode installed.

#### Build All Platforms at Once
```bash
npm run electron:build
```

## Features

### Desktop-Specific Features
- **System Tray**: App runs in system tray with quick access menu
- **Native Menus**: File, Edit, View, Window menus
- **Notifications**: Native system notifications
- **Auto-updates**: Can be configured with electron-updater

### Security
- Context isolation enabled
- Node integration disabled
- Secure preload script

## Troubleshooting

### Windows Build Issues
- Install Windows Build Tools: `npm install --global windows-build-tools`
- Run as Administrator if permissions fail

### Linux Build Issues
- Install required packages: `sudo apt-get install rpm fakeroot`
- For AppImage: `sudo apt-get install libfuse2`

### Icon Issues
- Ensure icons exist in `public/icons/` folder
- Windows needs `.ico` format (can use `.png` but `.ico` is recommended)
- Linux needs multiple PNG sizes in `public/icons/` folder

## Distribution

After building:

1. **Windows**: Distribute the `.exe` installer or portable version
2. **Linux**: 
   - `.AppImage` - Universal, no installation needed
   - `.deb` - For Debian/Ubuntu: `sudo dpkg -i package.deb`
   - `.rpm` - For Fedora/RHEL: `sudo rpm -i package.rpm`
3. **macOS**: Distribute the `.dmg` file

## Auto-Updates (Optional)

To enable auto-updates, install `electron-updater`:

```bash
npm install electron-updater
```

Add to `electron/main.js`:

```javascript
const { autoUpdater } = require('electron-updater');

app.whenReady().then(() => {
  autoUpdater.checkForUpdatesAndNotify();
});
```

Configure your update server in `electron-builder.json`:

```json
{
  "publish": {
    "provider": "github",
    "owner": "YOUR_USERNAME",
    "repo": "YOUR_REPO"
  }
}
```
