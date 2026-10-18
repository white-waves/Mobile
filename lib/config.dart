// Адреса сервера гри. За замовчуванням - продакшн-сервер на AWS.
//
// Для іншого сервера передай адресу під час збірки, без правки коду:
//   flutter run --dart-define=API_URL=http://192.168.0.1:3000
// - Android-емулятор: 'http://10.0.2.2:3000'
// - Фізичний пристрій у тій самій Wi-Fi мережі: 'http://<LAN-IP-ПК>:3000'
// - Пристрій по USB з `adb reverse tcp:3000 tcp:3000`: 'http://localhost:3000'
const String apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://13.60.154.115:3000');
final String wsBaseUrl = apiBaseUrl.replaceFirst('http', 'ws');
