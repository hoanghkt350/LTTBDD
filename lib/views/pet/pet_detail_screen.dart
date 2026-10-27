import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/pet_model.dart';
import '../../models/health_record_model.dart';
import '../../providers/pet_provider.dart';

class PetDetailScreen extends StatefulWidget {
  final Pet pet;

  const PetDetailScreen({super.key, required this.pet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  void _showAddHealthRecordDialog(BuildContext context) {
    final titleController = TextEditingController();
    final vetController = TextEditingController();
    final clinicController = TextEditingController();
    final costController = TextEditingController();
    String recordType = 'VACCINE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm Sổ Tiêm / Khám Bệnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: recordType,
                  decoration: const InputDecoration(labelText: 'Loại hồ sơ'),
                  items: const [
                    DropdownMenuItem(value: 'VACCINE', child: Text('Tiêm phòng Vaccine')),
                    DropdownMenuItem(value: 'DEWORMING', child: Text('Tẩy giun sán')),
                    DropdownMenuItem(value: 'CHECKUP', child: Text('Khám sức khỏe')),
                    DropdownMenuItem(value: 'SURGERY', child: Text('Tiểu phẫu / Triệt sản')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => recordType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung tiêm / khám *',
                    hintText: 'Vaccine 7 bệnh, Cắt móng...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vetController,
                  decoration: const InputDecoration(
                    labelText: 'Bác sĩ phụ trách',
                    hintText: 'BS. Tuấn Minh',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clinicController,
                  decoration: const InputDecoration(
                    labelText: 'Phòng khám thú y',
                    hintText: 'Bệnh viện thú y PetCare',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chi phí (VNĐ)',
                    hintText: '250000',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;

                final newRecord = HealthRecord(
                  petId: widget.pet.id!,
                  recordType: recordType,
                  title: titleController.text.trim(),
                  administeredDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  veterinarian: vetController.text.trim(),
                  clinicName: clinicController.text.trim(),
                  cost: double.tryParse(costController.text) ?? 0.0,
                );

                context.read<PetProvider>().addHealthRecord(newRecord);
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã thêm ghi chép sổ y bạ vào SQFlite!'),
                    backgroundColor: Color(0xFF4ECDC4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('LƯU'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final petProvider = context.watch<PetProvider>();
    final records = pet.id != null ? petProvider.getRecordsForPet(pet.id!) : <HealthRecord>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xác nhận xóa thú cưng?'),
                  content: Text('Bạn có chắc muốn xóa hồ sơ bé ${pet.name} khỏi hệ thống?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        if (pet.id != null) {
                          petProvider.deletePet(pet.id!);
                        }
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Thú cưng
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.15),
                      backgroundImage: pet.avatarCloudUrl != null ? NetworkImage(pet.avatarCloudUrl!) : null,
                      child: pet.avatarCloudUrl == null
                          ? const Icon(Icons.pets, size: 40, color: Color(0xFFFF6B6B))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pet.name,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pet.gender == 'Đực' ? Colors.blue.shade50 : Colors.pink.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pet.gender,
                                  style: TextStyle(
                                    color: pet.gender == 'Đực' ? Colors.blue : Colors.pink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${pet.species} • ${pet.breed}', style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.monitor_weight_outlined, size: 16, color: Color(0xFFFF6B6B)),
                              const SizedBox(width: 4),
                              Text('${pet.weight} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              const Icon(Icons.cake_outlined, size: 16, color: Color(0xFFFFBE0B)),
                              const SizedBox(width: 4),
                              Text(pet.birthDate, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sổ Tiêm Chủng & Sức Khỏe Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sổ Khám Bệnh & Tiêm Chủng (SQFlite)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm mới'),
                  onPressed: () => _showAddHealthRecordDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (records.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Chưa có lịch sử tiêm phòng hoặc khám bệnh', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final rec = records[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.vaccines_rounded, color: Color(0xFF1B998B)),
                      ),
                      title: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text('Ngày: ${rec.administeredDate} • ${rec.clinicName ?? "Tại nhà"}'),
                          if (rec.veterinarian != null && rec.veterinarian!.isNotEmpty)
                            Text('Bác sĩ: ${rec.veterinarian}', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: rec.cost > 0
                          ? Text(
                              _currencyFormat.format(rec.cost),
                              style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
