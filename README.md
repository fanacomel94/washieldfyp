HOW TO RUN

Backend:
Run backend: npm run dev in your Node project.
Start WhatsApp client: open browser http://127.0.0.1:3000/1/start, scan QR, wait until “Client is ready!” in backend logs.

Flutter (emulator):
AppConfig.baseUrl is http://10.0.2.2:3000 (Android emulator loopback to host).
Run the Flutter app on Android emulator.
In Encrypt Message screen:
Enter message + recipient public key.
Press Encrypt → _outputText becomes ciphertext.
Enter receiver phone as digits only (e.g. 60123456789).
Ensure Client ID is 1 (default).
Press Send via WhatsApp.
Receiver should see the ciphertext string in WhatsApp.

Flutter (real device):
On your laptop, run ipconfig and find LAN IP like 192.168.1.10.
Set AppConfig.baseUrl to http://192.168.1.10:3000. -> config.dart and .env
Ensure phone and laptop are on the same Wi‑Fi.
Run Flutter app on the phone and repeat the Encrypt + Send steps.


172.20.10.3
http://172.20.10.3:3000

