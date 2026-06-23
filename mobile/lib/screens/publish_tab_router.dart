import 'package:flutter/material.dart';

import '../services/data_service.dart';
import 'business_hub_screen.dart';
import '../services/onboarding_service.dart';
import '../widgets/app_tour_overlay.dart';
import 'publish_screen.dart';

/// Onglet central : particulier → annonce simple ; officiel → Espace Pro.
class PublishTabRouter extends StatefulWidget {
  const PublishTabRouter({super.key, this.onPublished, this.onGoHome});

  final VoidCallback? onPublished;
  final VoidCallback? onGoHome;

  @override
  State<PublishTabRouter> createState() => PublishTabRouterState();
}

class PublishTabRouterState extends State<PublishTabRouter> {
  final _data = DataService();
  final _particularKey = GlobalKey<PublishScreenState>();
  final _hubKey = GlobalKey<BusinessHubScreenState>();
  bool _isOfficial = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshRole();
  }

  Future<void> refreshRole() => _refreshRole();

  Future<void> _refreshRole() async {
    await _data.refreshUser();
    final official = _data.isOfficialSeller;
    if (mounted) {
      setState(() {
        _isOfficial = official;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTourPresenter.maybeShow(context, AppTourPage.publish);
      });
    }
  }

  void resetForm() {
    _particularKey.currentState?.resetForm();
    _hubKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isOfficial) {
      return BusinessHubScreen(
        key: _hubKey,
        onPublished: widget.onPublished,
        onGoHome: widget.onGoHome,
      );
    }
    return PublishScreen(
      key: _particularKey,
      onPublished: widget.onPublished,
      onGoHome: widget.onGoHome,
    );
  }
}
