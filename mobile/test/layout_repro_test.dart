import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sombateka/utils/marketplace_layout.dart';

void main() {
  testWidgets('detail screen sliver composition builds', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 360,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: MarketplaceLayout.centered(
                  GestureDetector(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [PageView()],
                    ),
                  ),
                  maxWidth: 1080,
                ),
              ),
            ),
            MarketplaceLayout.centeredSliver(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: const [Text('title'), SizedBox(height: 800)],
                  ),
                ),
              ),
              maxWidth: 1080,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.white,
          child: MarketplaceLayout.centeredBar(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('buttons')],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('title'), findsOneWidget);
    expect(find.text('buttons'), findsOneWidget);
  });

  testWidgets('wide screen centered slivers', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: CustomScrollView(
        slivers: [
          MarketplaceLayout.centeredSliver(
            const SliverToBoxAdapter(child: Text('head')),
          ),
          MarketplaceLayout.centeredSliver(
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, childAspectRatio: 0.78),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Text('item $i'),
                  childCount: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('item 0'), findsOneWidget);
  });
}
