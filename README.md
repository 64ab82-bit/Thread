# workspace

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

## Deployment

- Push to `main` triggers GitHub Actions workflow: `.github/workflows/deploy.yml`
- The Flutter web app is deployed to GitHub Pages automatically
- Public URL: https://64ab82-bit.github.io/Thread/

If this URL returns 404 initially, open repository Settings > Pages and ensure Source is set to GitHub Actions.

## API on Windows (always-on)

To keep the API running on `100.115.193.33` even after reboot/sleep, use Windows Scheduled Task.

1. Copy this repository to the Windows machine.
2. Open PowerShell as Administrator.
3. Run:

```powershell
cd <repo>\server\deploy\windows
.\publish-win.ps1
.\install-startup-task.ps1 -Port 5001
```

4. Open Windows Firewall for TCP `5001`.
5. Set GitHub Actions variable `API_BASE_URL` to:

```text
http://100.115.193.33:5001
```

6. Push to `main` to redeploy web.

Remove startup task:

```powershell
.\uninstall-startup-task.ps1
```

## CI re-run

Triggering workflow runs by pushing small commits to verify CI status.

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
