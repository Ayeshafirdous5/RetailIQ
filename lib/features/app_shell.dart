import 'package:flutter/material.dart';

import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import 'analytics/analytics_screen.dart';
import 'billing/billing_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'more/more_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _AppDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _AppDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Billing',
    ),
    _AppDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Inventory',
    ),
    _AppDestination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      label: 'Analytics',
    ),
    _AppDestination(icon: Icons.more_horiz, label: 'More'),
  ];

  static const _sections = [
    DashboardScreen(),
    BillingScreen(),
    InventoryScreen(),
    AnalyticsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutSize = AppBreakpoints.fromWidth(constraints.maxWidth);
        return Scaffold(
          body: switch (layoutSize) {
            AppLayoutSize.mobile => _content,
            AppLayoutSize.tablet => Row(
                children: [
                  _tabletNavigation,
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.border,
                  ),
                  Expanded(child: _content),
                ],
              ),
            AppLayoutSize.desktop => Row(
                children: [
                  _desktopNavigation,
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.border,
                  ),
                  Expanded(child: _content),
                ],
              ),
          },
          bottomNavigationBar: layoutSize == AppLayoutSize.mobile
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget get _content => IndexedStack(
        index: _selectedIndex,
        children: _sections,
      );

  Widget get _tabletNavigation => SafeArea(
        child: NavigationRail(
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          labelType: NavigationRailLabelType.all,
          groupAlignment: -1,
          indicatorColor: AppTheme.teal.withOpacity(0.14),
          selectedIconTheme: const IconThemeData(color: AppTheme.teal),
          unselectedIconTheme:
              const IconThemeData(color: AppTheme.secondaryText),
          selectedLabelTextStyle: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: AppTheme.secondaryText,
          ),
          onDestinationSelected: _selectDestination,
          destinations: [
            for (final destination in _destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(destination.label),
              ),
          ],
        ),
      );

  Widget get _desktopNavigation => SizedBox(
        width: 232,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x20,
                  AppSpacing.x20,
                  AppSpacing.x16,
                  AppSpacing.x16,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, color: AppTheme.teal),
                    const SizedBox(width: AppSpacing.x8),
                    Text(
                      'RetailIQ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: NavigationRail(
                  backgroundColor: Colors.white,
                  extended: true,
                  minExtendedWidth: 232,
                  selectedIndex: _selectedIndex,
                  groupAlignment: -1,
                  indicatorColor: AppTheme.teal.withOpacity(0.14),
                  selectedIconTheme: const IconThemeData(color: AppTheme.teal),
                  unselectedIconTheme:
                      const IconThemeData(color: AppTheme.secondaryText),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppTheme.secondaryText,
                  ),
                  onDestinationSelected: _selectDestination,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _AppDestination {
  const _AppDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}