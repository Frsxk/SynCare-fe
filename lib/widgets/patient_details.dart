import 'package:flutter/material.dart';

class PatientDetails extends StatelessWidget {
  const PatientDetails({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: ExpansionTile(
      internalAddSemanticForOnTap: true,
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      tilePadding: EdgeInsetsDirectional.zero,
      childrenPadding: const EdgeInsetsDirectional.only(bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          children[index],
        ],
      ],
    ),
  );
}
