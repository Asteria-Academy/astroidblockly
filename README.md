# Astroid Blockly — Build & Run Guide

This project contains two parts:

- `astroid-webview/` — a web UI built with TypeScript, Vite and Blockly.
- `astroid_test_webview_app/` — a Flutter app that displays the webview content using `flutter_inappwebview`.

This README explains how to build the webview, copy its `dist` output into the Flutter app's assets, and run the Flutter app locally.

## Prerequisites

- Node.js (LTS recommended) and npm
- Java JDK (for Android builds) if you plan to run Android
- Flutter SDK (stable channel)
- A code editor (VS Code recommended)

## 1) Build the webview (Node/Vite)

Open a terminal and change to the `astroid-webview` directory:

```powershell
cd astroid-webview
npm install
npm run build
```

After `npm run build`, Vite will create a `dist/` directory inside `astroid-webview` containing static files (HTML, JS, CSS, assets).

## 2) Copy or symlink `dist` into the Flutter app assets

The Flutter app expects the web content under `astroid_test_webview_app/assets/` according to `pubspec.yaml`.

You can either copy the files or create a symlink. On Windows (PowerShell), to copy:

```powershell
# From project root
Remove-Item -Recurse -Force astroid_test_webview_app\assets\dist\* -ErrorAction SilentlyContinue
Copy-Item -Path astroid-webview\dist\* -Destination astroid_test_webview_app\assets\ -Recurse
```

Or create a junction (symlink) so the Flutter app reads directly from the webview `dist` (useful during development):

```powershell
# Remove existing assets/dist if present
Remove-Item -Recurse -Force astroid_test_webview_app\assets\dist -ErrorAction SilentlyContinue
# Create a junction (Windows) from flutter assets/dist to webview dist
New-Item -ItemType Junction -Path astroid_test_webview_app\assets\dist -Target ..\astroid-webview\dist
```

Notes:
- Make sure `pubspec.yaml` includes `assets/index.html` or an assets folder that points to your HTML entry. This repo already lists `assets/index.html` and `assets/assets/` in `pubspec.yaml`.
- If you copy without maintaining `index.html` at `assets/index.html`, move/copy the webview `index.html` to `astroid_test_webview_app/assets/index.html`.

## 3) Flutter setup & run

Install Flutter and verify environment:

```powershell
# Install flutter (follow OS-specific instructions at https://flutter.dev)
flutter --version
flutter doctor
```

Add required packages (already present in `pubspec.yaml`):

```powershell
cd astroid_test_webview_app
flutter pub get
```

Run the app (choose a target: emulator, connected device):

```powershell
# Launch on connected device or emulator
flutter run

# Or build a release APK (Android)
flutter build apk --release
```

## 4) Development tips

- When iterating on the webview, use `npm run dev` in `astroid-webview` and rebuild (`npm run build`) when you want to push changes into the Flutter assets (or use the junction to avoid copying each time).
- If your Flutter app loads a cached HTML/JS file, do a hot restart in Flutter and/or clear the webview cache.
- For Android, ensure `android:usesCleartextTraffic` or proper CSP/CORs are set if loading local files.

## Troubleshooting

- "MissingConnection" or block serialization errors: ensure webview bundle is rebuilt and Flutter is loading the updated files; old bundles can cause Blockly runtime errors.
- If you get console errors about missing block types, ensure `import 'blockly/blocks'` is present in `astroid-webview/src/categories/index.ts` so built-in blocks are registered.
- If assets don't show up in Flutter, double-check `pubspec.yaml` `assets:` paths and run `flutter pub get`.

## Summary

1. Build webview: `cd astroid-webview && npm install && npm run build`
2. Copy or symlink `astroid-webview/dist` into `astroid_test_webview_app/assets/`
3. In Flutter app: `cd astroid_test_webview_app && flutter pub get && flutter run`

If you want, I can add a small npm script to automatically copy the `dist` files into the Flutter assets directory after `npm run build` (or a single PowerShell script). Would you like that? 
