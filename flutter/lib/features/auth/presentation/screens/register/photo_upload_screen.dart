import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../shared/widgets/common_widgets.dart';

/// Photo Upload Screen - Synced with React PhotoUploadScreen
class PhotoUploadScreen extends StatelessWidget {
  const PhotoUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photos')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add your best photos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Upload up to 6 photos. First photo will be your profile picture.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                ),
                itemCount: 6,
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.add_a_photo, color: Theme.of(context).hintColor),
                  ),
                ),
              ),
            ),
            AppButton(
              onPressed: () => context.push(AppRoutes.locationSetup),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
