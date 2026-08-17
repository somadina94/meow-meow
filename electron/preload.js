const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods to the renderer process
contextBridge.exposeInMainWorld('electronAPI', {
  // Platform info
  platform: process.platform,
  isElectron: true,
  
  // Window controls
  minimizeWindow: () => ipcRenderer.send('minimize-window'),
  maximizeWindow: () => ipcRenderer.send('maximize-window'),
  closeWindow: () => ipcRenderer.send('close-window'),
  
  // App info
  getVersion: () => ipcRenderer.invoke('get-version'),
  
  // Notifications
  showNotification: (title, body) => {
    new Notification(title, { body });
  }
});

// Log that preload script has loaded
console.log('Electron preload script loaded');
