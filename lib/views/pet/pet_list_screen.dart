import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pet_provider.dart';
import '../../services/app_error.dart';
import '../../widgets/care_widgets.dart';
import 'add_pet_screen.dart';
import 'pet_detail_screen.dart';
import 'pet_avatar.dart';
import 'reminder_dialog.dart';

class PetListScreen extends StatelessWidget {
  const PetListScreen({super.key});
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetProvider>();
    final locked = provider.isLoading || provider.isSyncing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thú cưng của tôi'),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ và khôi phục từ cloud',
            icon: const Icon(Icons.cloud_sync),
            onPressed: locked
                ? null
                : () async {
                    final ok = await provider.syncDataToCloud();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Đã đồng bộ hồ sơ, sổ sức khỏe và lịch nhắc.'
                                : provider.syncError ?? 'Chưa thể đồng bộ.',
                          ),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: locked
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPetScreen()),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thú cưng'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                if (provider.isSyncing) const LinearProgressIndicator(),
                if (provider.error != null)
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (provider.syncError != null)
                  Text(
                    'Chưa đồng bộ: ${provider.syncError}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                if (provider.notificationError != null)
                  Text(
                    provider.notificationError!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${provider.pets.length} hồ sơ • ${provider.pendingCount} thay đổi chờ đồng bộ',
                  ),
                ),
                if (provider.pets.isEmpty)
                  const CareEmptyState(
                    icon: Icons.pets_rounded,
                    title: 'Gia đình nhỏ bắt đầu từ đây',
                    message: 'Thêm hồ sơ đầu tiên hoặc bấm Đồng bộ để khôi phục dữ liệu từ tài khoản.',
                  ),
                ...provider.pets.map(
                  (pet) => Card(
                    child: ListTile(
                      leading: PetAvatar(pet: pet, radius: 26),
                      title: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${pet.species} • ${pet.breed}\n${pet.weight} kg • ${pet.gender}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PetDetailScreen(pet: pet),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lịch nhắc hàng ngày',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_alarm),
                      onPressed: locked || provider.pets.isEmpty
                          ? null
                          : () => showDialog(
                              context: context,
                              builder: (_) => const ReminderDialog(),
                            ),
                    ),
                  ],
                ),
                if (provider.reminders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có lịch nhắc.'),
                  ),
                ...provider.reminders.map(
                  (rem) => Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(rem.title),
                          subtitle: Text('Hàng ngày lúc ${rem.reminderTime}'),
                          value: rem.isActive == 1,
                          onChanged: locked
                              ? null
                              : (active) => _action(
                                  context,
                                  () =>
                                      provider.toggleReminder(rem.id!, active),
                                ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: locked
                                  ? null
                                  : () => showDialog(
                                      context: context,
                                      builder: (_) =>
                                          ReminderDialog(reminder: rem),
                                    ),
                              child: const Text('Sửa'),
                            ),
                            TextButton(
                              onPressed: locked
                                  ? null
                                  : () => _action(
                                      context,
                                      () => provider.deleteReminder(rem.id!),
                                    ),
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
