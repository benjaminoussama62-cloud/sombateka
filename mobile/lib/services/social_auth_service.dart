import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';



import '../config/app_config.dart';

import '../services/app_services.dart';

import '../services/data_service.dart';
import '../utils/friendly_error.dart';



/// Connexion Google / Apple via SDK natifs + vérification id_token côté API.

class SocialAuthService {

  SocialAuthService._();

  static final instance = SocialAuthService._();



  bool _statusLoaded = false;

  bool _googleAvailable = false;

  bool _appleAvailable = false;



  bool get googleAvailable => _googleAvailable;

  bool get appleAvailable => _appleAvailable && !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);



  Future<void> refreshStatus() async {

    if (!AppConfig.showGoogleLogin && !AppConfig.showAppleLogin) {

      _googleAvailable = false;

      _appleAvailable = false;

      _statusLoaded = true;

      return;

    }

    try {

      final r = await AppServices.instance.api.get<Map<String, dynamic>>('/auth/social/status');

      final data = r.data ?? {};

      _googleAvailable = AppConfig.showGoogleLogin && data['google'] == true;

      _appleAvailable = AppConfig.showAppleLogin && data['apple'] == true;

    } catch (_) {

      _googleAvailable = AppConfig.showGoogleLogin &&

          (AppConfig.googleWebClientId.isNotEmpty || !kIsWeb);

      _appleAvailable = AppConfig.showAppleLogin && AppConfig.appleSignInEnabled;

    }

    _statusLoaded = true;

  }



  Future<void> ensureStatus() async {

    if (!_statusLoaded) await refreshStatus();

  }



  GoogleSignIn _googleSignIn(String webClientId) {

    return GoogleSignIn(

      scopes: const ['openid', 'email', 'profile'],

      clientId: kIsWeb && webClientId.isNotEmpty ? webClientId : null,

      serverClientId: !kIsWeb && webClientId.isNotEmpty ? webClientId : null,

    );

  }



  Future<void> signInWithGoogle(BuildContext context) async {

    await ensureStatus();

    if (!_googleAvailable) {

      _unavailable(context, 'Google');

      return;

    }

    try {

      final webClientId = AppConfig.googleWebClientId;

      final googleSignIn = _googleSignIn(webClientId);

      final account = await googleSignIn.signIn();

      if (account == null) return;



      var auth = await account.authentication;

      var idToken = auth.idToken;

      var accessToken = auth.accessToken;



      // PWA web : parfois id_token absent au 1er appel — retenter une fois.

      if ((idToken == null || idToken.isEmpty) && kIsWeb) {

        auth = await account.authentication;

        idToken = auth.idToken;

        accessToken ??= auth.accessToken;

      }



      if (idToken != null && idToken.isNotEmpty) {

        await AppServices.instance.auth.socialLogin(

          provider: 'google',

          idToken: idToken,

          email: account.email,

          displayName: account.displayName,

        );

      } else if (accessToken != null && accessToken.isNotEmpty) {

        await AppServices.instance.auth.socialLogin(

          provider: 'google',

          accessToken: accessToken,

          email: account.email,

          displayName: account.displayName,

        );

      } else {

        throw Exception(

          kIsWeb

              ? 'Jeton Google manquant — activez People API dans Google Cloud, puis réessayez.'

              : 'Jeton Google manquant — vérifiez google-services.json et SHA-256 release',

        );

      }



      await DataService().refreshUser();

      await DataService().refreshListings();

    } catch (e) {

      if (context.mounted) {

        final msg = e.toString();

        final hint = msg.contains('origin_mismatch') || msg.contains('400')

            ? 'Ajoutez https://sombatekaonline.com dans Google Cloud Console → Credentials → Origines JavaScript autorisées (voir mobile/docs/GOOGLE_PWA_ORIGINS.md).'

            : 'Connexion Google impossible : $e';

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(hint), duration: const Duration(seconds: 6)),

        );

      }

      rethrow;

    }

  }



  Future<void> signInWithApple(BuildContext context) async {

    await ensureStatus();

    if (!_appleAvailable) {

      _unavailable(context, 'Apple');

      return;

    }

    try {

      final credential = await SignInWithApple.getAppleIDCredential(

        scopes: [

          AppleIDAuthorizationScopes.email,

          AppleIDAuthorizationScopes.fullName,

        ],

      );

      final idToken = credential.identityToken;

      if (idToken == null || idToken.isEmpty) {

        throw Exception('Jeton Apple manquant');

      }

      final parts = <String>[];

      if (credential.givenName != null && credential.givenName!.isNotEmpty) {

        parts.add(credential.givenName!);

      }

      if (credential.familyName != null && credential.familyName!.isNotEmpty) {

        parts.add(credential.familyName!);

      }

      final displayName = parts.isEmpty ? null : parts.join(' ');

      await AppServices.instance.auth.socialLogin(

        provider: 'apple',

        idToken: idToken,

        email: credential.email,

        displayName: displayName,

      );

      await DataService().refreshUser();

      await DataService().refreshListings();

    } on SignInWithAppleAuthorizationException catch (e) {

      if (e.code == AuthorizationErrorCode.canceled) return;

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Connexion Apple annulée ou refusée')),

        );

      }

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(friendlyError(e, fallback: 'Connexion Apple impossible. Réessayez.'))),

        );

      }

      rethrow;

    }

  }



  void _unavailable(BuildContext context, String provider) {

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          '$provider pas encore activé. Utilisez e-mail et mot de passe, '

          'ou configurez OAuth (voir mobile/docs/SOCIAL_AUTH_SETUP.md).',

        ),

      ),

    );

  }

}


