#!/usr/bin/env node

const { spawn } = require('child_process');
const os = require('os');
const path = require('path');

console.log("\n==========================================");
console.log("🐈 Kitty Enterprise Agent Installer");
console.log("==========================================\n");

const isWin = os.platform() === 'win32';
const scriptName = isWin ? 'bootstrap-ssh-install.ps1' : 'bootstrap-ssh-install.sh';
const scriptPath = path.join(__dirname, '..', 'scripts', scriptName);

let child;
if (isWin) {
    child = spawn('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath
    ], { stdio: 'inherit' });
} else {
    child = spawn('bash', [scriptPath], { stdio: 'inherit' });
}

child.on('exit', (code) => {
    process.exit(code || 0);
});
