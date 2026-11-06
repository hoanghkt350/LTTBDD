import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/clinic_provider.dart';
import '../../services/app_error.dart';

class ClinicScreen extends StatefulWidget {
  const ClinicScreen({super.key});
  @override
  State<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends State<ClinicScreen> {
  bool _only247 = false;
  String _query = '';
  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Thiết bị không mở được liên kết này.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final clinics = provider.clinics
        .where(
          (c) =>
              (!_only247 || c.isOpen247) &&
              ('${c.name} ${c.address}').toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng khám thú y'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading
                ? null
                : provider.loadClinicsAndArticles,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm tên hoặc địa chỉ',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SwitchListTile(
            title: const Text('Chỉ hiển thị cơ sở 24/7'),
            value: _only247,
            onChanged: (v) => setState(() => _only247 = v),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Thông tin do cửa hàng cập nhật. Gọi xác nhận giờ hoạt động trước khi đến.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                provider.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: clinics.isEmpty
                ? const Center(child: Text('Chưa có phòng khám phù hợp.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: clinics
                        .map(
                          (clinic) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clinic.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(clinic.address),
                                  Text(clinic.openHours),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: clinic.services
                                        .map((s) => Chip(label: Text(s)))
                                        .toList(),
                                  ),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.directions),
                                        label: const Text('Chỉ đường'),
                                        onPressed: () => _open(
                                          Uri.https(
                                            'www.google.com',
                                            '/maps/dir/',
                                            {
                                              'api': '1',
                                              'destination':
                                                  '${clinic.latitude},${clinic.longitude}',
                                            },
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.phone),
                                        label: const Text('Gọi điện'),
                                        onPressed: () => _open(
                                          Uri(
                                            scheme: 'tel',
                                            path: clinic.phone,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
