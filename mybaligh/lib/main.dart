
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:screen_protector/screen_protector.dart';
/* ============================== THEME / CONFIG ============================== */
const _primary = Color(0xFF673AB7); // purple
const _accent = Color(0xFFF7A600); // orange
const _idleLockSeconds = 90;

ThemeData appTheme() => ThemeData(
useMaterial3: true,
colorScheme: ColorScheme.fromSeed(
seedColor: _primary,
primary: _primary,
secondary: _accent,
),
scaffoldBackgroundColor: const Color(0xFFF6F7FB),
appBarTheme: const AppBarTheme(
backgroundColor: _primary,
foregroundColor: Colors.white,
centerTitle: true,

)
)
  filledButtonTheme: FilledButtonThemeData(
style: FilledButton.styleFrom(
backgroundColor: _accent,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
),
),
inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
),
);

//-----------------------
class Vault {
static const _s = FlutterSecureStorage(
aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
static Future<void> write(String k, String v) => _s.write(key: k, value: v);
static Future<String?> read(String k) => _s.read(key: k);
static Future<void> del(String k) => _s.delete(key: k);

static Future<void> saveSession(String user) async {
await write('logged_user', user);
}

static Future<void> clearSession() async {
await del('logged_user');
}
"6: زر تبديل إظهار/إخفاء كلمة المرور
static Future<bool> verifyPassword(String pw) async {
final salt = await read('pw_salt') ?? '';
final saved = await read('pw_hash');
return saved == _hash(pw, salt);
}
}

/* ================================== MOCK API ================================== */
class MockApi {
// محاكاة طلب شبكة (تأخير + رد)
static Future<LoginResult> login({
required String memberId,
required String password,
}) async {
await Future.delayed(const Duration(milliseconds: 700));
final goodId = await Vault.read('user_id') ?? '';
final okPw = await Vault.verifyPassword(password);
if (memberId == goodId && okPw) {
// أحياناً نطلب OTP (عرض تعليمي)
final needOtp = (DateTime.now().second % 2 == 0);
if (needOtp) {
final otpToken = base64UrlEncode(
utf8.encode('otp:${DateTime.now().millisecondsSinceEpoch}'),
);
return LoginResult(needOtp: true, otpToken: otpToken);
}
return LoginResult(needOtp: false);
}
throw AuthError('بيانات الدخول غير صحيحة.');
}

static Future<void> verifyOtp({
required String token,
required String code,
}) async {
await Future.delayed(const Duration(milliseconds: 600));
if (code != '000000' && code != '123456') {
throw AuthError('رمز التحقق غير صحيح.');
}
}

static Future<void> changePin({
required String oldPin,
required String newPin,
}) async {
await Future.delayed(const Duration(milliseconds: 500));
final ok = await Vault.verifyPassword(oldPin);
if (!ok) throw AuthError('الرمز الحالي غير صحيح.');
final salt = await Vault.read('pw_salt') ?? '';
await Vault.write('pw_hash', Vault._hash(newPin, salt));
}
}

class LoginResult {
final bool needOtp;
final String? otpToken;
LoginResult({required this.needOtp, this.otpToken});
}

class AuthError implements Exception {
final String message;
AuthError(this.message);
@override
String toString() => message;
}

/* ==================================== APP ==================================== */
void main() async {
WidgetsFlutterBinding.ensureInitialized();
try {
await ScreenProtector.preventScreenshotOn();
await ScreenProtector.protectDataLeakageOn();
} catch (_) {}
await Vault.ensureDefaultUser();
runApp(const UniKuraimiDemo());
}

class UniKuraimiDemo extends StatefulWidget {
const UniKuraimiDemo({super.key});
@override
State<UniKuraimiDemo> createState() => _AppState();
}

class _AppState extends State<UniKuraimiDemo> with WidgetsBindingObserver {
final navKey = GlobalKey<NavigatorState>();
Timer? _idle;
@override
void initState() {
super.initState();
WidgetsBinding.instance.addObserver(this);
}

@override
void dispose() {
WidgetsBinding.instance.removeObserver(this);
_idle?.cancel();
super.dispose();
}

