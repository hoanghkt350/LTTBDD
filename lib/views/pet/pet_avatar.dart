import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';

class PetAvatar extends StatelessWidget {
  final Pet pet;
  final double radius;
  const PetAvatar({super.key, required this.pet, this.radius = 32});
  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    final url = pet.avatarCloudUrl;
    if (url != null && url.isNotEmpty) {
      try {
        image = url.startsWith('data:image/')
            ? MemoryImage(base64Decode(url.split(',').last))
            : NetworkImage(url);
      } catch (_) {
        image = null;
      }
    }
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: image == null
            ? const ColoredBox(
                color: AppTheme.mint,
                child: Icon(Icons.pets, color: AppTheme.secondary),
              )
            : Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.pets),
              ),
      ),
    );
  }
}
