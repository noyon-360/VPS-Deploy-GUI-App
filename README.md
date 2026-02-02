# 🚀 Easy Deploy Tool

A powerful, local-only Flutter Desktop application designed to automate backend and dashboard deployments for Node.js and NestJS projects on VPS servers.

> **"I genuinely love solving problems. I always look for ways to reduce repetitive work so I can focus more on building logic and improving systems."**

## 💡 Why This Tool Exists

I built this application to solve a real problem I faced while deploying over 20 backend and dashboard applications on VPS servers. The process was always manual and repetitive—typing the same commands, setting up the same configurations, and handling the same server setup steps again and again.

While CI/CD helps with updates, the initial server configuration and first-time setup remained a bottleneck. I initially used Bash scripts, but they became complex to manage.

This GUI-based application automates those bash commands in a structured, user-friendly way, storing client credentials locally and executing setup commands automatically. It turns a manual, error-prone process into a consistent, one-click operation.

## ✨ Key Features

- **✅ Automated Setup**: Installs and checks for essential tools (Nginx, Git, Node.js, PM2) automatically.
- **🔍 Server Discovery**:
  - **Auto-Detect Applications**: Scans `/var/www` to find existing deployments.
  - **Smart Identification**: Identifies Node.js/PM2 processes, their ports, and associated Nginx domains.
  - **Git Info Extraction**: Automatically pulls repository URLs and branch names from the server.
- **📂 Multi-Project Management**: Organize multiple clients and projects with local credential storage.
- **🔐 Flexible Authentication**:
  - **SSH Keys**: Uses your system's `~/.ssh/config` for seamless access.
  - **SSH Passwords**: Fallback support for servers using password authentication.
- **🛠️ Verification & Health Checks**: instantly verify if `nginx`, `git`, `node`, or `pm2` are installed and running correctly.
- **📜 Interactive Logs**: Watch live command output and deployment logs in real-time.
- **🌑 Premium Design**: A user-friendly, dark-themed interface built with Flutter.

## 📸 Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/9eb8bf5f-a439-452e-96a6-4321fa5f9884" width="45%" />
  <img src="https://github.com/user-attachments/assets/407fff2f-88f4-4aa8-8c10-89d71893490a" width="45%" />
  <img src="https://github.com/user-attachments/assets/ae5f48fc-8ddd-4d66-ae16-538a622bcf60" width="45%" />
  <img src="https://github.com/user-attachments/assets/fbfedb03-92ee-4404-ac25-6d4f55984004" width="45%" />
  <img src="https://github.com/user-attachments/assets/570f1e3f-ecd5-403b-82f3-a73d7dd96fbd" width="45%" />
  <img src="https://github.com/user-attachments/assets/96eeaaca-e76b-44f3-b0d9-e2e869809e93" width="45%" />
  <img src="https://github.com/user-attachments/assets/d93f67fd-57eb-40a7-a0e7-58b72a4ea903" width="91%" />
</p>

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: Installed and configured on your machine.
- **SSH Client**: Ensure `ssh` is available in your terminal.
- **Server Access**: A non-root user with `sudo` privileges on the destination VPS.

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
Click the **+** button to add a new server connection. You can use an SSH alias (from your config) or a direct `user@ip` address.

### 2. Discover & Verify
Use the **Verification** tools to scan your server. The app will tell you what's already installed and list any running applications it finds, including their ports and domain info.

### 3. Deploying Projects
- **Clone & Setup**: Automatically clone private repositories using saved Git credentials.
- **Deploy**: Run your custom install (e.g., `npm install`) and start commands (e.g., `pm2 start...`) with a single click.
- **Update**: Pull the latest code and restart your application without logging in manually.

---

## 🛠️ Technology Stack
- **Framework**: [Flutter](https://flutter.dev) (Desktop for Windows)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **SSH Integration**: [dartssh2](https://pub.dev/packages/dartssh2)
- **Storage**: JSON-based local persistence
