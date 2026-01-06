import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SquareTile extends StatelessWidget{
  final String imagePath;
  const SquareTile({
    super.key, 
    required this.imagePath
    });

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: FutureBuilder<Uint8List?>(
        future: _loadImageBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final bytes = snapshot.data;
            if (bytes != null) {
              return Image.memory(bytes, height: 40, fit: BoxFit.contain);
            } else {
              return const Icon(Icons.broken_image, size: 32, color: Colors.black45);
            }
          }
          return const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2));
        },
      ),
    );
  }

  Future<Uint8List?> _loadImageBytes() async {
    final filename = imagePath.split('/').last;
    final candidates = <String>[
      imagePath,
      imagePath.replaceFirst(RegExp(r'^lib/login_ui/'), ''),
      'lib/images/$filename',
      'assets/images/$filename',
      'images/$filename',
    ];

    for (final path in candidates) {
      try {
        final bd = await rootBundle.load(path);
        return bd.buffer.asUint8List();
      } catch (_) {
        // try next
      }
    }
    return null;
  }
}