import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/clinic_provider.dart';
import '../../models/clinic_model.dart';

class ClinicScreen extends StatefulWidget {
  const ClinicScreen({super.key});

  @override
  State<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends State<ClinicScreen> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadClinicsAndArticles();
    });
  }

  // Gọi điện thoại trực tiếp qua url_launcher (Bài 5 mục 5.2.7.1)
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gọi đến số $phoneNumber')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    List<Clinic> displayedClinics = provider.clinics;

    if (_selectedFilter == '24_7') {
      displayedClinics = displayedClinics.where((c) => c.isOpen247).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng Khám & Trạm Thú Y'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 44,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: const Text('Tất cả phòng khám'),
                  selected: _selectedFilter == 'ALL',
                  selectedColor: const Color(0xFF4ECDC4),
                  labelStyle: TextStyle(
                    color: _selectedFilter == 'ALL' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency_outlined, size: 16, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text('Cấp cứu 24/7'),
                    ],
                  ),
                  selected: _selectedFilter == '24_7',
                  selectedColor: Colors.redAccent,
                  labelStyle: TextStyle(
                    color: _selectedFilter == '24_7' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = '24_7'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : displayedClinics.isEmpty
              ? const Center(child: Text('Không có cơ sở thú y nào phù hợp.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedClinics.length,
                  itemBuilder: (context, index) {
                    final clinic = displayedClinics[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (clinic.isOpen247 ? Colors.redAccent : const Color(0xFF4ECDC4)).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    clinic.isOpen247 ? Icons.local_hospital_rounded : Icons.pets_rounded,
                                    color: clinic.isOpen247 ? Colors.redAccent : const Color(0xFF1B998B),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        clinic.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFFFBE0B), size: 18),
                                          const SizedBox(width: 4),
                                          Text('${clinic.rating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.near_me_outlined, size: 14, color: Colors.blue.shade600),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Cách bạn ${clinic.distanceKm} km',
                                            style: TextStyle(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Address & Open Hours
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    clinic.address,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  clinic.openHours,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: clinic.isOpen247 ? Colors.redAccent : Colors.grey.shade700,
                                    fontWeight: clinic.isOpen247 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Services chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: clinic.services.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(s, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                );
                              }).toList(),
                            ),
                            const Divider(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.directions_outlined, size: 18),
                                    label: const Text('Chỉ Đường'),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đang mở bản đồ dẫn đường đến ${clinic.name}'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: clinic.isOpen247 ? Colors.redAccent : const Color(0xFF4ECDC4),
                                    ),
                                    icon: const Icon(Icons.phone_in_talk, size: 18),
                                    label: const Text('GỌI NGAY'),
                                    onPressed: () => _makePhoneCall(clinic.phone),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
