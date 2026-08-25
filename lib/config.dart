// Продакшн-сервер на AWS.
//
// Для локальної розробки замінюй тимчасово на:
// - Android-емулятор: 'http://10.0.2.2:3000'
// - Фізичний пристрій у тій самій Wi-Fi мережі: 'http://<LAN-IP-ПК>:3000'
// - iOS-симулятор / фізичний пристрій по USB (adb reverse): 'http://localhost:3000'
const String apiBaseUrl = 'http://13.60.154.115:3000';
final String wsBaseUrl = apiBaseUrl.replaceFirst('http', 'ws');
