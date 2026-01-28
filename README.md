# 🚀 Easy Deploy Tool

A powerful, local-only Flutter Desktop application designed to manage and automate deployments for multiple clients across various servers. No more repeating manual SSH steps—deploy your backends with a single click.

## ✨ Key Features

- **📂 Multi-Client Management**: Save and organize server details, repo URLs, and paths for unlimited clients.
- **🔐 Flexible Authentication**:
  - **SSH Keys**: Seamlessly uses your system's existing SSH configuration (`~/.ssh/config`).
  - **SSH Passwords**: Support for servers where keys aren't yet configured (powered by `dartssh2`).
- **📦 Private Repo Support**: Authenticated HTTPS cloning using Git Usernames and Personal Access Tokens (PAT).
- **🛠️ Customizable Commands**: Define your own installation (e.g., `npm install`, `yarn`) and start commands (e.g., `pm2 start server.js`).
- **📜 Real-Time Logs**: Watch live output from your server during deployment via a built-in terminal view.
- **🌑 Premium Design**: Sleek Material 3 dark theme with modern typography.

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: Installed and configured on your machine.
- **SSH Client**: Ensure `ssh` is available in your terminal (included in Windows 10/11).
- **Server Access**: A non-root user with `sudo` privileges on the destination server.

### Installation
1. Clone this project to your local machine.
2. Open a terminal in the project directory.
3. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
4. Run the application:
   ```powershell
   flutter run -d windows
   ```

## 📖 Usage Guide

### 1. Adding a Client
Click the **+** button. You'll need to provide:
- **SSH Connection**: Either an alias from your `~/.ssh/config` or a direct `user@ip`.
- **Git Repo**: Use HTTPS for token-based authentication or SSH if your keys are on the server.
- **Commands**: Defaults are set for Node.js/PM2, but you can change them for any technology.

### 2. Performing a Deploy
- **Initial Deploy**: Use this for fresh servers. It installs Git, Nginx, Node.js, and PM2 automatically.
- **Update Deploy**: Use this for daily updates. It pulls the latest code, runs your install command, and restarts the app.

---

## 🛠️ Technology Stack
- **Framework**: [Flutter](https://flutter.dev) (Desktop)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **SSH**: [dartssh2](https://pub.dev/packages/dartssh2)
- **Storage**: JSON-based local persistence
