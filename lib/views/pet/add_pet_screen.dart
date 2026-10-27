import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/pet_model.dart';
import '../../providers/pet_provider.dart';

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _microchipController = TextEditingController();

  String _selectedSpecies = 'Chó';
  String _selectedGender = 'Đực';
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _microchipController.dispose();
    super.dispose();
  }

  // Chọn ảnh qua ImagePicker (Bài 5 mục 5.2.4.2)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFFF6B6B)),
              title: const Text('Chụp ảnh từ Camera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF4ECDC4)),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final weight = double.tryParse(_weightController.text) ?? 1.0;
      final dateFormat = DateFormat('yyyy-MM-dd');

      final newPet = Pet(
        name: _nameController.text.trim(),
        species: _selectedSpecies,
        breed: _breedController.text.trim(),
        gender: _selectedGender,
        birthDate: dateFormat.format(_birthDate),
        weight: weight,
        microchipId: _microchipController.text.trim().isEmpty ? null : _microchipController.text.trim(),
        avatarPath: _imageFile?.path,
        avatarCloudUrl: _selectedSpecies == 'Chó'
            ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=400&q=80'
            : 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=400&q=80',
        isSynced: 0,
      );

      context.read<PetProvider>().addPet(newPet);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu hồ sơ thú cưng vào SQFlite thành công!'),
          backgroundColor: Color(0xFF4ECDC4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Hồ Sơ Thú Cưng'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.12),
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null
                          ? const Icon(Icons.pets, size: 54, color: Color(0xFFFF6B6B))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thú cưng *',
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'Ví dụ: Milo, Bông, Miu...',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên bé' : null,
              ),
              const SizedBox(height: 16),

              // Species & Gender Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSpecies,
                      decoration: const InputDecoration(
                        labelText: 'Loài *',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Chó', child: Text('Chó')),
                        DropdownMenuItem(value: 'Mèo', child: Text('Mèo')),
                        DropdownMenuItem(value: 'Chim', child: Text('Chim')),
                        DropdownMenuItem(value: 'Hamster', child: Text('Hamster')),
                        DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSpecies = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Giới tính *',
                        prefixIcon: Icon(Icons.transgender_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Đực', child: Text('Đực')),
                        DropdownMenuItem(value: 'Cái', child: Text('Cái')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Breed
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Giống loài *',
                  prefixIcon: Icon(Icons.cruelty_free_outlined),
                  hintText: 'Poodle, Corgi, Mèo Anh...',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập giống' : null,
              ),
              const SizedBox(height: 16),

              // Weight & Birth Date Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cân nặng (kg) *',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nhập cân nặng';
                        if (double.tryParse(val) == null) return 'Phải là số';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: _selectBirthDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày sinh',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(dateFormat.format(_birthDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Microchip
              TextFormField(
                controller: _microchipController,
                decoration: const InputDecoration(
                  labelText: 'Mã số vi chip (Tùy chọn)',
                  prefixIcon: Icon(Icons.qr_code_outlined),
                  hintText: 'VN-123456...',
                ),
              ),
              const SizedBox(height: 30),

              // Button Save
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('LƯU HỒ SƠ THÚ CƯNG'),
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
