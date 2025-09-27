
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
