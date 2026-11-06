import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/pet_model.dart';
import '../../providers/pet_provider.dart';
import '../../services/app_error.dart';
import 'pet_avatar.dart';

class AddPetScreen extends StatefulWidget {
  final Pet? pet;
  const AddPetScreen({super.key, this.pet});
  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _breed, _weight, _chip;
  late String _species, _gender;
  late DateTime _birth;
  String? _avatar;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _name = TextEditingController(text: pet?.name);
    _breed = TextEditingController(text: pet?.breed);
    _weight = TextEditingController(text: pet?.weight.toString());
    _chip = TextEditingController(text: pet?.microchipId);
    _species = pet?.species ?? 'Chó';
    _gender = pet?.gender ?? 'Đực';
    _birth = DateTime.tryParse(pet?.birthDate ?? '') ?? DateTime.now();
    _avatar = pet?.avatarCloudUrl;
  }

  @override
  void dispose() {
    for (final c in [_name, _breed, _weight, _chip]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 60,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 180000) {
        throw StateError('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn.');
      }
      if (mounted) {
        setState(
          () => _avatar = 'data:image/jpeg;base64,${base64Encode(bytes)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<PetProvider>();
    try {
      final pet = Pet(
        id: widget.pet?.id,
        serverId: widget.pet?.serverId,
        name: _name.text.trim(),
        species: _species,
        breed: _breed.text.trim(),
        gender: _gender,
        birthDate: DateFormat('yyyy-MM-dd').format(_birth),
        weight: double.parse(_weight.text.replaceAll(',', '.')),
        microchipId: _chip.text.trim(),
        avatarCloudUrl: _avatar,
      );
      if (widget.pet == null) {
        await provider.addPet(pet);
      } else {
        await provider.updatePet(pet);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = Pet(
      name: '',
      species: '',
      breed: '',
      gender: '',
      birthDate: '',
      weight: 1,
      avatarCloudUrl: _avatar,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pet == null ? 'Thêm thú cưng' : 'Chỉnh sửa hồ sơ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            children: [
              GestureDetector(
                onTap: _saving ? null : _photo,
                child: PetAvatar(pet: preview, radius: 52),
              ),
              TextButton(
                onPressed: _saving ? null : _photo,
                child: const Text('Chọn ảnh thú cưng'),
              ),
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Tên thú cưng'),
                validator: (v) => (v?.trim().isNotEmpty ?? false)
                    ? null
                    : 'Nhập tên thú cưng',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _species,
                decoration: const InputDecoration(labelText: 'Loài'),
                items: ['Chó', 'Mèo', 'Chim', 'Thỏ', 'Khác']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _species = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _breed,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Giống'),
                validator: (v) => (v?.trim().isNotEmpty ?? false)
                    ? null
                    : 'Nhập giống hoặc “Chưa rõ”',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: ['Đực', 'Cái', 'Chưa rõ']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
              ListTile(
                title: const Text('Ngày sinh'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_birth)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birth,
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && mounted) setState(() => _birth = date);
                },
              ),
              TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                validator: (v) {
                  final weight = double.tryParse(
                    (v ?? '').replaceAll(',', '.'),
                  );
                  return weight == null ||
                          !weight.isFinite ||
                          weight <= 0 ||
                          weight > 500
                      ? 'Cân nặng phải lớn hơn 0 và tối đa 500 kg'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chip,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Mã microchip (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Đang lưu…' : 'LƯU HỒ SƠ'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hồ sơ được lưu trên máy. Bấm Đồng bộ để sao lưu lên tài khoản của bạn.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
