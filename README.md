# WAShield — Quick Start

## How to run

### Prerequisites
- Node.js (>= 14) and npm/yarn
- Flutter SDK and Android SDK (emulator) or a real Android device
- For Windows: use `ipconfig` to find your LAN IP when running on a real device

### Backend (Node)
1. Open the Node backend project root (directory containing package.json).
2. Install dependencies:
```bash
npm install
```
3. If a `.env.example` exists, copy and edit values:
```bash
cp .env.example .env
# edit .env to set PORT, any keys, etc.
```
4. Start dev server:
```bash
npm run dev
```
5. Start a WhatsApp client and scan the QR: open `http://127.0.0.1:3000/1/start` and wait for "Client is ready!" in backend logs.

### Flutter (emulator)
1. From the Flutter project root:
```bash
flutter pub get
```
2. Set backend base URL for Android emulator:
- `AppConfig.baseUrl = 'http://10.0.2.2:3000'` (emulator → host loopback).
3. Run the app on an Android emulator:
```bash
flutter run
```
4. Usage: In Encrypt Message screen enter plaintext + recipient public key → tap **Encrypt** → copy ciphertext → set receiver phone as digits only (e.g. `60123456789`) and ensure Client ID is `1` → **Send via WhatsApp**.

### Flutter (real device)
1. On your laptop run `ipconfig` and note your LAN IP (e.g. `192.168.1.10`).
2. Set `AppConfig.baseUrl` (or `.env`/config file) to `http://<your-ip>:3000`.
3. Ensure phone and laptop are on the same Wi‑Fi.
4. Run the app on your device:
```bash
flutter run -d <device-id>
```

### Common commands
- Run Flutter tests:
```bash
flutter test
```
- Troubleshooting:
  - If backend unreachable, confirm `AppConfig.baseUrl`, firewall, and that backend is running.
  - If decryption fails, follow the "Debugging tips & AUTH FAILs" section below.

---

