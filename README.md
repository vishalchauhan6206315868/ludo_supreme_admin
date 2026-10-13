# LudoSupreme Admin Panel (Flutter)

## Setup
1. Flutter SDK install karein (3.x)
2. Is folder me terminal kholein:
   flutter create .          # android/ios/web folders generate honge (lib/ aur pubspec.yaml safe rahenge)
   flutter pub get
   flutter run -d chrome     # ya android emulator / device
3. Login screen par "Demo mode" se bina backend ke UI dekh sakte hain.

## Demo mode
Login screen par "Demo mode" dabayein. Koi network call nahi hoti: saara data `lib/services/demo_data.dart`
me in-memory hai aur real backend jaisi hi shape (pagination, filters, detail, write actions) deta hai.
Block/unblock, coins adjust, banners, tickets reply sab session ke dauran kaam karte hain.
Top par "Exit Demo" banner se bahar aa sakte hain.

## Backend connect karna
Login screen par Backend URL daalein ya build time par set karein:

    flutter run --dart-define=API_BASE_URL=https://yourdomain.com/api

- Android emulator: http://10.0.2.2:4000/api
- Real phone (debug): http://<PC-IP>:4000/api  (cleartext sirf debug/profile build me allowed)
- Release / production: HTTPS zaroori hai
- Web: backend CORS me panel ka origin allow karein, aur HTTPS page se HTTP API nahi chalegi

Response contract (sab `{ success, data: {...} }`):
- GET /admin/dashboard -> data.{stats, live, growth, modes, revenue, topGames, recentUsers, activities, onlineUsers, health}
  health keys: dbPingMs, uptimeSeconds, memoryMB (backend, database)
- List endpoints -> data.{users|games|tickets|transactions|admins|logs}, data.pagination.{page,limit,total,totalPages}
- Exact shapes ke liye `lib/services/demo_data.dart` ko reference maanein.

Auth header: Authorization: Bearer <token>. Login ka 401 = galat password (logout trigger nahi hota),
baaki endpoints ka 401 = session expired -> login screen.

## Tests
    flutter pub get && flutter analyze && flutter test
