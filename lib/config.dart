// Фізичний Android-пристрій по USB: `adb reverse tcp:3000 tcp:3000`,
// тоді localhost пристрою прокидається на localhost ПК.
//
// Інші варіанти для розробки:
// - Android-емулятор: 'http://10.0.2.2:3000'
// - Фізичний пристрій у тій самій Wi-Fi мережі: 'http://<LAN-IP-ПК>:3000'
// - iOS-симулятор: 'http://localhost:3000'
const String apiBaseUrl = 'http://localhost:3000';
final String wsBaseUrl = apiBaseUrl.replaceFirst('http', 'ws');
