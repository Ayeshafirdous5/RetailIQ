import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_placeholder.dart';
import '../../services/auth_service.dart';
import 'data_export_screen.dart';
import '../purchases/purchases_screen.dart';
import '../suppliers/suppliers_screen.dart';
import 'insights_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('Customers', Icons.people_outline, 'Manage customer records'),
      ('Suppliers', Icons.business_outlined, 'Keep supplier details organised'),
      ('Purchases', Icons.local_shipping_outlined, 'Record supplier purchases'),
      (
        'Export Data',
        Icons.file_download_outlined,
        'Export sales, inventory and customer data'
      ),
      ('Insights', Icons.lightbulb_outline, 'Review future business insights'),
      ('Profile', Icons.person_outline, 'Update your store profile'),
      ('Settings', Icons.settings_outlined, 'Configure app preferences'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
          final padding = AppSpacing.pagePadding(layout).copyWith(
            top: AppSpacing.x8,
            bottom: AppSpacing.x32,
          );
          return ListView.separated(
            padding: padding,
            itemCount: options.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, index) {
              if (index == options.length) {
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x16,
                      vertical: AppSpacing.x4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout, color: AppTheme.error),
                    ),
                    title: Text(
                      'Log out',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.error,
                      ),
                    ),
                    onTap: () => AuthService().signOut(),
                  ),
                );
              }

              final option = options[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x16,
                    vertical: AppSpacing.x8,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(option.$2, color: AppTheme.teal),
                  ),
                  title: Text(
                    option.$1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    option.$3,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.secondaryText),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.secondaryText,
                  ),
                  onTap: () {
                    final page = option.$1 == 'Export Data'
                        ? const DataExportScreen()
                        : option.$1 == 'Suppliers'
                            ? const SuppliersScreen()
                            : option.$1 == 'Purchases'
                                ? const PurchasesScreen()
                                : option.$1 == 'Insights'
                                    ? const InsightsScreen()
                                    : SectionPlaceholder(
                                        title: option.$1,
                                        description:
                                            '${option.$3}. This section will be built in a future phase.',
                                        icon: option.$2,
                                      );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => page),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
