
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

/* ==================================== OTP ==================================== */
class OtpScreen extends StatefulWidget {
  final String token;
  const OtpScreen({super.key, required this.token});
  @override
  State<OtpScreen> createState() => _OtpState();
}

class _OtpState extends State<OtpScreen> {
  final _otp = TextEditingController();
  bool _loading = false;
  String? _err;
  Future<void> _verify() async {
    setState(() => {_loading = true, _err = null});
    try {
      await MockApi.verifyOtp(token: widget.token, code: _otp.text.trim());
      final user = await Vault.read('user_id') ?? '';
      await Vault.saveSession(user);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق OTP')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('أدخل رمز التحقق (للتجربة: 000000 أو 123456)'),
          const SizedBox(height: 8),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'رمز التحقق',
              counterText: '',
            ),
            onSubmitted: (_) => _verify(),
          ),
          if (_err != null) ...[
            const SizedBox(height: 6),
            Text(_err!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

/* ==================================== HOME ==================================== */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int _tab = 0;
  bool _hide = true;
  String _name = '';
  String _acct = '';
  String _currency = 'YER';
  String _balance = '0';

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  Future<void> _loadHeader() async {
    _name = await Vault.read('display_name') ?? 'عميلنا العزيز';
    _acct = await Vault.read('account_no') ?? '********';
    _currency = await Vault.read('currency') ?? 'YER';
    _balance = await Vault.read('balance') ?? '0';
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await Vault.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text(' $title')),
        ),
      ),
    );
  }

  final _actions = const [
    {'icon': Icons.shopping_bag, 'label': 'الدفع والسداد (حاسب)'},
    {'icon': Icons.account_balance, 'label': 'الخدمات البنكية'},
    {'icon': Icons.currency_exchange, 'label': 'الكريمي إكسبريس'},
    {'icon': Icons.qr_code, 'label': 'خدمات القسائم'},
    {'icon': Icons.settings_suggest, 'label': 'خدمة التمويل'},
    {'icon': Icons.paid, 'label': 'فلوس'},
    {'icon': Icons.credit_card, 'label': 'خدمات البطاقة'},
    {'icon': Icons.apps, 'label': 'خدمات أخرى'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: _primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'بياناتي'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _acct,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(
                        _hide ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hide ? '**** $_currency' : '$_balance $_currency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _open('عرض البيان'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                  ),
                  child: const Text('عرض البيان'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'خدمي إلى ...',
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .95,
            ),
            itemBuilder: (_, i) {
              final a = _actions[i];
              return _Tile(
                icon: a['icon'] as IconData,
                label: a['label'] as String,
                onTap: () => _open(a['label'] as String),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _primary, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/* ================================= SETTINGS ================================= */
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  bool _bio = true;
  double _sessionMins = _idleLockSeconds / 60;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('اللغة'), trailing: const Text('العربية')),
          const Divider(),
          ListTile(
            title: const Text('مدة الجلسة'),
            subtitle: Text('${_sessionMins.toStringAsFixed(0)} دقيقة'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                min: 1,
                max: 30,
                divisions: 29,
                value: _sessionMins,
                onChanged: (v) => setState(() => _sessionMins = v),
              ),
            ),
          ),
  const Divider(),
          SwitchListTile(
            value: _bio,
            onChanged: (v) => setState(() => _bio = v),
            title: const Text('انقر لتفعيل بصمة اليد'),
            activeColor: _primary,
          ),
          const Divider(),
          ListTile(
            title: const Text('إنشاء/تغيير رمز التعريف الشخصي'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePinPage()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('الحساب الافتراضي'),
            subtitle: FutureBuilder(
              future: Vault.read('account_no'),
              builder: (_, s) => Text(s.data?.toString() ?? '—'),
            ),
          ),
        ],
      ),
    );
  }
}



