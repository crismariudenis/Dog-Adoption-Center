import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> with SingleTickerProviderStateMixin {
  XFile? _selectedImage;
  bool _scanning = false;
  List<Map<String, dynamic>> _predictions = [];
  late AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();

  final List<String> _dogBreeds = [
    'Golden Retriever',
    'Doberman Pinscher',
    'Labrador Retriever',
    'Siberian Husky',
    'German Shepherd',
    'Beagle',
    'Poodle',
    'English Bulldog',
    'Boxer',
    'Rottweiler',
    'Chihuahua',
    'Great Dane'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _predictions = [];
        });
        _runMockClassification(image.name);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera/gallery: $e')),
      );
    }
  }

  void _runMockClassification(String filename) {
    setState(() {
      _scanning = true;
    });
    _animationController.repeat(reverse: true);

    // Simulate classification delay of 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      _animationController.stop();

      // Attempt to intelligently guess breed from filename to make it interactive!
      String primaryBreed = '';
      final lowerName = filename.toLowerCase();
      if (lowerName.contains('gold') || lowerName.contains('buddy')) {
        primaryBreed = 'Golden Retriever';
      } else if (lowerName.contains('dober') || lowerName.contains('max')) {
        primaryBreed = 'Doberman Pinscher';
      } else if (lowerName.contains('labra') || lowerName.contains('bella')) {
        primaryBreed = 'Labrador Retriever';
      } else if (lowerName.contains('husky') || lowerName.contains('luna')) {
        primaryBreed = 'Siberian Husky';
      } else if (lowerName.contains('beagl') || lowerName.contains('charlie')) {
        primaryBreed = 'Beagle';
      } else if (lowerName.contains('bulldog') || lowerName.contains('rocky')) {
        primaryBreed = 'English Bulldog';
      } else {
        // Randomly choose
        primaryBreed = _dogBreeds[Random().nextInt(_dogBreeds.length)];
      }

      // Generate related fallback predictions
      final remainingBreeds = _dogBreeds.where((b) => b != primaryBreed).toList()..shuffle();
      final score1 = 0.70 + Random().nextDouble() * 0.20; // 70% to 90%
      final score2 = (1.0 - score1) * (0.5 + Random().nextDouble() * 0.3); // part of remainder
      final score3 = 1.0 - score1 - score2; // rest of remainder

      setState(() {
        _scanning = false;
        _predictions = [
          {'className': primaryBreed, 'probability': score1},
          {'className': remainingBreeds[0], 'probability': score2},
          {'className': remainingBreeds[1], 'probability': score3},
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dog Species Demo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan or select a photo of a dog to classify its breed using a simulated AI scanner.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : () => _getImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning ? null : () => _getImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Scanner Area
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 300,
              child: Stack(
                children: [
                  // Image Preview
                  Center(
                    child: _selectedImage != null
                        ? kIsWeb
                            ? Image.network(_selectedImage!.path, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                            : Image.file(File(_selectedImage!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No image selected', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),

                  // Scanning animation overlay
                  if (_scanning)
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (ctx, child) {
                        return Stack(
                          children: [
                            Container(
                              color: Colors.black26,
                            ),
                            Positioned(
                              top: _animationController.value * 300,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.cyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyan.withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Colors.cyan),
                                  SizedBox(height: 12),
                                  Text(
                                    'SCANNING SPECIES...',
                                    style: TextStyle(
                                      color: Colors.cyan,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Predictions List Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Predictions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 12),
                  if (_scanning)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Loading model & analyzing pixels...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    )
                  else if (_predictions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No predictions yet. Take a photo or upload an image to begin.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  else
                    ..._predictions.map((p) {
                      final prob = p['probability'] as double;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  p['className'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${(prob * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: prob,
                                minHeight: 6,
                                backgroundColor: Colors.amber[100],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
