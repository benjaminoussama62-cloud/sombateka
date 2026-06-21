import 'dart:js_interop';

@JS('window.stApiBaseUrl')
external String? get _windowStApiBaseUrl;

String? getWebApiBaseUrl() => _windowStApiBaseUrl;
