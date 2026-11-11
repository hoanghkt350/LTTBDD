import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pet_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/clinic_provider.dart';
import '../../models/article_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/care_widgets.dart';
import '../../widgets/pawpals_logo.dart';
import '../pet/add_pet_screen.dart';
import '../pet/pet_avatar.dart';
import '../pet/pet_detail_screen.dart';
import '../pet/health_appointments_section.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pets = context.watch<PetProvider>();
    final shop = context.watch<ShopProvider>();
    final content = context.watch<ClinicProvider>();
    final reminders = pets.reminders.where((r) => r.isActive == 1).toList();
    void addPet() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPetScreen()),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawPalsLogo(size: 34),
            SizedBox(width: 9),
            Text('PawPals'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lịch nhắc',
            onPressed: () => onTabChange(1),
            icon: Badge(
              isLabelVisible: reminders.isNotEmpty,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            pets.syncDataToCloud(),
            shop.fetchProducts(),
            content.loadClinicsAndArticles(),
          ]);
        },
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: box.maxWidth > 900
                  ? (box.maxWidth - 900) / 2 + 24
                  : 22,
              vertical: 12,
            ),
            children: [
              const Text(
                'MỘT NGÀY THẬT ĐÁNG YÊU',
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chào ${auth.user?.displayName ?? 'bạn'}!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Cùng chăm sóc những người bạn nhỏ của bạn.',
                style: TextStyle(color: AppTheme.textLight),
              ),
              const SizedBox(height: 24),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -35,
                      top: -35,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: const BoxDecoration(
                          color: Color(0xFF325447),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 26,
                      child: Transform.rotate(
                        angle: -.25,
                        child: const Icon(
                          Icons.pets_rounded,
                          size: 78,
                          color: Color(0xFF83A48B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LỚN LÊN CÙNG YÊU THƯƠNG',
                            style: TextStyle(
                              color: Color(0xFFD3DEC0),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.only(right: 56),
                            child: Text(
                              'Chăm sóc mỗi ngày,\nyêu thương trọn vẹn.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: -.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Mã PAWPALS10 giảm 10% tiền hàng\nMiễn phí giao hàng từ 300.000đ',
                            style: TextStyle(
                              color: Color(0xFFD3DEC0),
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => onTabChange(2),
                            label: const Text('Khám phá cửa hàng'),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            iconAlignment: IconAlignment.end,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeading('Bạn muốn làm gì?'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = [
                    (
                      Icons.add_rounded,
                      'Thêm thú cưng',
                      const Color(0xFFFBEDE4),
                      AppTheme.primary,
                      addPet,
                    ),
                    (
                      Icons.alarm_rounded,
                      'Nhắc lịch',
                      AppTheme.mint,
                      AppTheme.secondary,
                      () => onTabChange(1),
                    ),
                    (
                      Icons.medical_services_outlined,
                      'Phòng khám',
                      const Color(0xFFEDF0FA),
                      const Color(0xFF697BB0),
                      () => onTabChange(3),
                    ),
                    (
                      Icons.shopping_bag_outlined,
                      'Mua sắm',
                      const Color(0xFFFBF2DE),
                      const Color(0xFFAE8433),
                      () => onTabChange(2),
                    ),
                  ];
                  final columns = constraints.maxWidth < 340 ? 2 : 4;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions
                        .map(
                          (a) => SizedBox(
                            width:
                                (constraints.maxWidth - (columns - 1) * 10) /
                                columns,
                            child: Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: AppTheme.line),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: a.$5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(13),
                                        decoration: BoxDecoration(
                                          color: a.$3,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Icon(
                                          a.$1,
                                          color: a.$4,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        a.$2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              SectionHeading(
                'Gia đình nhỏ của bạn',
                action: 'Xem tất cả',
                onTap: () => onTabChange(1),
              ),
              if (pets.pets.isEmpty)
                CareEmptyState(
                  icon: Icons.pets_rounded,
                  title: 'Thêm một người bạn nhỏ',
                  message: 'Lưu hồ sơ và theo dõi hành trình lớn lên của bé.',
                  action: 'Thêm thú cưng',
                  onTap: addPet,
                ),
              ...pets.pets
                  .take(3)
                  .map(
                    (pet) => Card(
                      child: ListTile(
                        leading: PetAvatar(pet: pet, radius: 27),
                        title: Text(pet.name),
                        subtitle: Text('${pet.breed} • ${pet.weight} kg'),
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PetDetailScreen(pet: pet),
                          ),
                        ),
                      ),
                    ),
                  ),
              SectionHeading(
                'Lịch tiêm & tái khám',
                action: 'Xem tất cả',
                onTap: () => onTabChange(1),
              ),
              const HealthAppointmentsSection(limit: 3),
              SectionHeading(
                'Lịch nhắc đang bật',
                action: '${reminders.length} lịch',
                onTap: () => onTabChange(1),
              ),
              if (pets.isLoading || pets.isSyncing)
                const LinearProgressIndicator(),
              if (pets.error != null)
                Text(pets.error!, style: const TextStyle(color: Colors.red)),
              if (pets.notificationError != null)
                Text(
                  pets.notificationError!,
                  style: const TextStyle(color: Colors.orange),
                ),
              if (reminders.isEmpty)
                CareEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Sẵn sàng cho một ngày mới',
                  message: 'Chưa có lịch nhắc. Thêm lịch ở mục Thú cưng.',
                  action: 'Quản lý lịch nhắc',
                  onTap: () => onTabChange(1),
                ),
              ...reminders.map(
                (r) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.mint,
                      child: Icon(
                        Icons.alarm_rounded,
                        color: AppTheme.secondary,
                      ),
                    ),
                    title: Text(r.title),
                    subtitle: const Text('Nhắc bạn mỗi ngày'),
                    trailing: Text(
                      r.reminderTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary,
                        fontSize: 18,
                      ),
                    ),
                    onTap: () => onTabChange(1),
                  ),
                ),
              ),
              SectionHeading(
                'Sản phẩm nổi bật',
                action: 'Xem tất cả',
                onTap: () => onTabChange(2),
              ),
              if (shop.isLoading) const LinearProgressIndicator(),
              if (shop.error != null)
                Text(shop.error!, style: const TextStyle(color: Colors.red)),
              if (!shop.isLoading && shop.featured.isEmpty)
                const CareEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Góc mua sắm cho bé',
                  message: 'Cửa hàng chưa cập nhật sản phẩm nổi bật.',
                ),
              if (shop.featured.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: constraints.maxWidth < 320
                        ? 1
                        : constraints.maxWidth > 650
                        ? 4
                        : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 12,
                    childAspectRatio: .62,
                    children: shop.featured
                        .take(4)
                        .map((p) => ProductCard(product: p))
                        .toList(),
                  ),
                ),
              const SectionHeading('Cẩm nang chăm sóc'),
              if (content.isLoading) const LinearProgressIndicator(),
              if (content.error != null)
                Text(content.error!, style: const TextStyle(color: Colors.red)),
              if (!content.isLoading && content.articles.isEmpty)
                const CareEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Hiểu bé thêm mỗi ngày',
                  message: 'Chưa có bài viết.',
                ),
              ...content.articles.map(
                (article) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.mint,
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.secondary,
                      ),
                    ),
                    title: Text(article.title),
                    subtitle: Text(
                      '${article.category} • ${article.readTimeMinutes} phút đọc',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ArticleScreen(article: article),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleScreen extends StatelessWidget {
  final Article article;
  const _ArticleScreen({required this.article});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(article.category)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(article.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          '${article.author} • ${article.publishedAt}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text(
          article.summary,
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.7),
        ),
        const SizedBox(height: 16),
        SelectableText(
          article.content,
          style: const TextStyle(fontSize: 16, height: 1.8),
        ),
      ],
    ),
  );
}
