import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/form/create_account_form.dart';
import '../../services/api_client.dart';

class ClientCreateScreen extends StatelessWidget {
  const ClientCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşletme Ekle')),
      body: CreateAccountForm(
        title: 'İşletme Ekle',
        userType: 'client',
      ),
    );
  }
}
