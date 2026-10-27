import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/reminder_model.dart';
import 'add_pet_screen.dart';
import 'pet_detail_screen.dart';

class PetListScreen extends StatelessWidget {
  const PetListScreen({super.key});

  void _showAddReminderDialog(BuildContext context, PetProvider provider) {
    if (provider.pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất một thú cưng trước!')),
      );
      return;
    }

    final titleController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    int selectedPetId = provider.pets.first.id!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm Nhắc Nhở Thông Minh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedPetId,
                decoration: const InputDecoration(labelText: 'Chọn thú cưng'),
                items: provider.pets
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedPetId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung nhắc *',
                  hintText: 'Cho ăn hạt, Uống thuốc tim...',
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Giờ nhắc nhở:'),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: selectedTime);
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('HỦY')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final formattedTime =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                provider.addReminder(Reminder(
                  petId: selectedPetId,
                  title: titleController.text.trim(),
                  reminderTime: formattedTime,
                  notificationId: DateTime.now().millisecondsSinceEpoch % 100000,
                  repeatInterval: 'DAILY',
                ));

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã tạo lịch nhắc lúc $formattedTime!'),
                    backgroundColor: const Color(0xFF4ECDC4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('TẠO NHẮC NHỞ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petProvider = context.watch<PetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thú Cưng Của Tôi'),
        actions: [
          // Nút Đồng bộ SQFlite lên Firebase
          IconButton(
            tooltip: 'Đồng bộ lên Firebase Cloud',
            icon: petProvider.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFFFF6B6B), strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined, color: Color(0xFF4ECDC4)),
            onPressed: petProvider.isSyncing
                ? null
                : () async {
                    final ok = await petProvider.syncDataToCloud();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? '🎉 Đã sao lưu dữ liệu SQFlite lên Firebase Cloud thành công!'
                            : 'Đồng bộ thất bại!'),
                        backgroundColor: const Color(0xFF4ECDC4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF6B6B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm Thú Cưng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPetScreen()),
          );
        },
      ),
      body: petProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Danh sách thẻ Thú cưng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hồ Sơ Thú Cưng (${petProvider.pets.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Lưu SQFlite', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (petProvider.pets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.pets, size: 54, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Bạn chưa có bé thú cưng nào!', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Bấm nút "Thêm Thú Cưng" bên dưới để tạo hồ sơ đầu tiên.'),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: petProvider.pets.length,
                      itemBuilder: (context, index) {
                        final pet = petProvider.pets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => PetDetailScreen(pet: pet)),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.12),
                                    backgroundImage: pet.avatarCloudUrl != null
                                        ? NetworkImage(pet.avatarCloudUrl!)
                                        : null,
                                    child: pet.avatarCloudUrl == null
                                        ? const Icon(Icons.pets, color: Color(0xFFFF6B6B), size: 30)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              pet.name,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: pet.gender == 'Đực' ? Colors.blue.shade50 : Colors.pink.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                pet.gender,
                                                style: TextStyle(
                                                  color: pet.gender == 'Đực' ? Colors.blue : Colors.pink,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${pet.species} • ${pet.breed}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text('Cân nặng: ${pet.weight} kg • Sinh: ${pet.birthDate}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      ),
                  const SizedBox(height: 28),

                  // Lịch nhắc nhở (Reminders)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nhắc Nhở Định Kỳ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_alarm, size: 18),
                        label: const Text('Thêm lịch'),
                        onPressed: () => _showAddReminderDialog(context, petProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (petProvider.reminders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Chưa có lịch nhắc nhở nào.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: petProvider.reminders.length,
                      itemBuilder: (context, index) {
                        final rem = petProvider.reminders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            secondary: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFFF6B6B)),
                            ),
                            title: Text(rem.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Hàng ngày vào lúc: ${rem.reminderTime}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            value: rem.isActive == 1,
                            activeColor: const Color(0xFFFF6B6B),
                            onChanged: (val) {
                              if (rem.id != null) {
                                petProvider.toggleReminder(rem.id!, val);
                              }
                            },
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
