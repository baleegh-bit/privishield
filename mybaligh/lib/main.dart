
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


@override
void didChangeAppLifecycleState(AppLifecycleState s) {
if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
_lockNow();
}
}

void _resetIdle() {
_idle?.cancel();
_idle = Timer(const Duration(seconds: _idleLockSeconds), _lockNow);
}

Future<void> _lockNow() async {
await Vault.clearSession();
navKey.currentState?.popUntil((r) => r.isFirst);
}

@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'Uni Kuraimi-like',
debugShowCheckedModeBanner: false,
theme: appTheme(),
locale: const Locale('ar'),
supportedLocales: const [Locale('ar'), Locale('en')],
localizationsDelegates: const [
GlobalMaterialLocalizations.delegate,
GlobalWidgetsLocalizations.delegate,
GlobalCupertinoLocalizations.delegate,
],
navigatorKey: navKey,
builder: (_, child) => Directionality(
textDirection: TextDirection.rtl,
child: GestureDetector(
behavior: HitTestBehavior.translucent,
onTap: _resetIdle,
onPanDown: (_) => _resetIdle(),
child: child,
),
),
home: const _Gate(),
);
}
}

class _Gate extends StatefulWidget {
const _Gate();
@override
State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
late Future<bool> _f;
@override
void initState() {
super.initState();
_f = Vault.isLogged();
}

@override
Widget build(BuildContext c) {
return FutureBuilder<bool>(
future: _f,
builder: (_, s) =>
s.data == true ? const HomeScreen() : const LoginScreen(),
);
}
}

/* =================================== LOGIN =================================== */
class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});
@override
State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
final _member = TextEditingController();
final _pass = TextEditingController();
bool _hide = true,
_loading = false,
_isOffline = false,
_offlineLogin = false;
String? _err;
final _auth = LocalAuthentication();
StreamSubscription? _connSub;

@override
void initState() {
super.initState();
_listenConnectivity();
}

@override
void dispose() {
_connSub?.cancel();
_member.dispose();
_pass.dispose();
super.dispose();
}

void _listenConnectivity() async {
final current = await Connectivity().checkConnectivity();
final ConnectivityResult r0 = current is List<ConnectivityResult>
? (current.isNotEmpty ? current.first : ConnectivityResult.none)
    : current as ConnectivityResult;
setState(() => _isOffline = (r0 == ConnectivityResult.none));
_connSub = Connectivity().onConnectivityChanged.listen((event) {
final ConnectivityResult r = event is List<ConnectivityResult>
? (event.isNotEmpty ? event.first : ConnectivityResult.none)
    : event as ConnectivityResult;
if (mounted) setState(() => _isOffline = (r == ConnectivityResult.none));
});
}

Future<void> _login() async {
FocusScope.of(context).unfocus();
setState(() => {_loading = true, _err = null});
try {
if (_offlineLogin) {
if (await Vault.isLogged()) {
if (!mounted) return;
Navigator.pushReplacement(
context,
MaterialPageRoute(builder: (_) => const HomeScreen()),
);
} else {
setState(() => _err = 'لا توجد جلسة محفوظة لفتحها بدون إنترنت.');
}
} else {
final res = await MockApi.login(
memberId: _member.text.trim(),
password: _pass.text.trim(),
);
if (res.needOtp) {
if (!mounted) return;
final ok = await Navigator.push<bool>(
context,
MaterialPageRoute(builder: (_) => OtpScreen(token: res.otpToken!)),
);
if (ok == true && mounted) {
Navigator.pushReplacement(
context,
MaterialPageRoute(builder: (_) => const HomeScreen()),
);
}
} else {
await Vault.saveSession(_member.text.trim());
if (!mounted) return;
Navigator.pushReplacement(
context,
MaterialPageRoute(builder: (_) => const HomeScreen()),
);
}
}
} on AuthError catch (e) {
setState(() => _err = e.message);
} finally {
if (mounted) setState(() => _loading = false);
}
}


Future<void> _biometric() async {
setState(() => {_loading = true, _err = null});
try {
final can =
await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
if (!can) {
setState(() => _err = 'جهازك لا يدعم البصمة.');
} else {
final ok = await _auth.authenticate(
localizedReason: 'افتح الجلسة ببصمة الجهاز',
options: const AuthenticationOptions(
biometricOnly: true,
stickyAuth: true,
),
);
if (ok && await Vault.isLogged()) {
if (!mounted) return;
Navigator.pushReplacement(
context,
MaterialPageRoute(builder: (_) => const HomeScreen()),
);
} else if (!ok) {
setState(() => _err = 'لم يتم التحقق بالبصمة.');
}
}
} catch (_) {
setState(() => _err = 'تعذّر استخدام البصمة.');
}
if (mounted) setState(() => _loading = false);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: Column(
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 250),
height: _isOffline ? 40 : 0,
width: double.infinity,
color: Colors.red,
alignment: Alignment.center,
child: _isOffline
? const Text(
'الرجاء التحقق من الاتصال بالإنترنت',
style: TextStyle(color: Colors.white),
)
    : null,
),
Expanded(
child: ListView(
padding: const EdgeInsets.all(20),
children: [
Row(
children: [
const Icon(
Icons.account_balance,
color: _primary,
size: 36,
),
const SizedBox(width: 8),
const Expanded(
child: Text(
'بنك الكريمي',
style: TextStyle(fontWeight: FontWeight.w700),
),
),
],
),
const SizedBox(height: 16),
Container(
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
),
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Text(
'رقم المميّز',
style: TextStyle(
color: _primary,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 6),
TextField(
controller: _member,
keyboardType: TextInputType.number,
decoration: const InputDecoration(
hintText: 'ادخل رقم المميّز',
),
),
const SizedBox(height: 12),
const Text(
'كلمة المرور',
style: TextStyle(
color: _primary,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 6),
TextField(
controller: _pass,
obscureText: _hide,
decoration: InputDecoration(
hintText: 'ادخل كلمة المرور',
suffixIcon: IconButton(
icon: Icon(
_hide ? Icons.visibility : Icons.visibility_off,
),
onPressed: () => setState(() => _hide = !_hide),
),
),
),
const SizedBox(height: 12),
Row(
children: [
IconButton(
onPressed: _loading ? null : _biometric,
icon: const Icon(
Icons.fingerprint,
size: 30,
color: _accent,
),
),
const SizedBox(width: 8),
Expanded(
child: Row(
children: [
Checkbox(
value: _offlineLogin,
onChanged: (v) => setState(
() => _offlineLogin = v ?? false,
),
),
const Text('الدخول بدون إنترنت'),
const Spacer(),
TextButton(
onPressed: () =>
ScaffoldMessenger.of(
context,
).showSnackBar(
const SnackBar(
content: Text('ميزة تعليمية.'),
),
),
child: const Text('نسيت كلمة المرور؟'),
),
],
),
),
],
),

