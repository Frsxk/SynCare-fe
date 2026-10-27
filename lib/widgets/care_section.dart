import 'package:flutter/material.dart';

class CareSection extends StatelessWidget {
  const CareSection({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsetsDirectional.all(24), child: child),
  );
}

class CareAction extends StatelessWidget {
  const CareAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: Text(description),
      onTap: onTap,
    ),
  );
}
