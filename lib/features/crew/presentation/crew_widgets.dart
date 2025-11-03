import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CrewLogo extends StatelessWidget {
  const CrewLogo({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(initials),
              )
            : _placeholder(initials),
      ),
    );
  }

  Widget _placeholder(String initials) {
    return Container(
      color: Colors.blueGrey.shade100,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}
