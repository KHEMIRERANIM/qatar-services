import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pro_service.dart';

/// Vérification d'identité native (caméra Flutter) — utilisée en mode développement
/// quand Veriff web / tunnel n'est pas disponible.
class NativeIdentityVerificationScreen extends StatefulWidget {
  final String sessionId;

  const NativeIdentityVerificationScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<NativeIdentityVerificationScreen> createState() =>
      _NativeIdentityVerificationScreenState();
}

class _NativeIdentityVerificationScreenState
    extends State<NativeIdentityVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  int _step = 0;
  String? _rectoPath;
  String? _versoPath;
  bool _isSubmitting = false;

  static const _steps = [
    'Placez le recto de votre QID dans le cadre',
    'Placez le verso de votre QID dans le cadre',
    'Confirmez la vérification',
  ];

  Future<void> _capture(String side) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() {
      if (side == 'recto') {
        _rectoPath = image.path;
        _step = 1;
      } else {
        _versoPath = image.path;
        _step = 2;
      }
    });
  }

  Future<void> _confirm() async {
    if (_rectoPath == null || _versoPath == null) return;

    setState(() => _isSubmitting = true);

    final result = await ProService.completeNativeVeriff(
      sessionId: widget.sessionId,
      status: 'approved',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message'] as String? ??
              'Une erreur est survenue. Veuillez réessayer plus tard.',
        ),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F3C),
      appBar: AppBar(
        title: const Text(
          'Vérification d\'identité',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D1F3C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgress(),
              const SizedBox(height: 32),
              Expanded(child: _buildStepContent()),
              if (_isSubmitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
                    ),
                  ),
                )
              else
                _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFC9A84C) : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _step < 2 ? Icons.credit_card : Icons.verified_user,
          size: 72,
          color: const Color(0xFFC9A84C),
        ),
        const SizedBox(height: 24),
        Text(
          _steps[_step],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _step < 2
              ? 'Utilisez la caméra pour photographier votre carte d\'identité Qatar.'
              : 'Vos photos seront analysées pour confirmer votre identité.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        if (_step == 0 && _rectoPath != null) ...[
          const SizedBox(height: 20),
          _previewThumb(_rectoPath!),
        ],
        if (_step == 1 && _versoPath != null) ...[
          const SizedBox(height: 20),
          _previewThumb(_versoPath!),
        ],
        if (_step == 2) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              if (_rectoPath != null) Expanded(child: _previewThumb(_rectoPath!)),
              const SizedBox(width: 12),
              if (_versoPath != null) Expanded(child: _previewThumb(_versoPath!)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _previewThumb(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        height: 100,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildActionButton() {
    if (_step == 0) {
      return ElevatedButton.icon(
        onPressed: () => _capture('recto'),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Photographier le recto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC9A84C),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    if (_step == 1) {
      return ElevatedButton.icon(
        onPressed: () => _capture('verso'),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Photographier le verso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC9A84C),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: _confirm,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      label: const Text('Confirmer la vérification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2D9B6F),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
