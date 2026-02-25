import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/form/create_account_form.dart';
import 'package:flutter/material.dart';

class _CreateAccountSheetStub extends StatelessWidget {
  final String title;
  final bool isCourier;
  const _CreateAccountSheetStub({
    super.key,
    required this.title,
    required this.isCourier,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets; // klavye alanı

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          expand: false,
          builder: (ctx, scrollController) {
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: CreateAccountForm(
                      title: title,
                      userType: 'delivery_man',
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
