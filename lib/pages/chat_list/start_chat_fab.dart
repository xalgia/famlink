import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import '../../config/themes.dart';
import 'chat_list.dart';

class StartChatFloatingActionButton extends StatelessWidget {
  final ActiveFilter activeFilter;
  final ValueNotifier<bool> scrolledToTop;
  final bool roomsIsEmpty;
  final void Function() createNewSpace;

  const StartChatFloatingActionButton({
    super.key,
    required this.activeFilter,
    required this.scrolledToTop,
    required this.roomsIsEmpty,
    required this.createNewSpace,
  });

  void _onPressed(BuildContext context) async {
    context.go('/dashboard/rooms');
     }

  IconData get icon {
    switch (activeFilter) {
      case ActiveFilter.allChats:
      case ActiveFilter.unread:
        return Icons.add_outlined;
      case ActiveFilter.groups:
        return Icons.group_add_outlined;
      case ActiveFilter.spaces:
        return Icons.workspaces_outlined;
      case ActiveFilter.messages:
        return Icons.person_add_outlined;
    }
  }

  String getLabel(BuildContext context) {
    switch (activeFilter) {
      case ActiveFilter.allChats:
        return L10n.of(context)!.start;
      case ActiveFilter.unread:
        return L10n.of(context)!.start;
      case ActiveFilter.groups:
        return L10n.of(context)!.start;
      case ActiveFilter.spaces:
        return L10n.of(context)!.start;
      case ActiveFilter.messages:
        return L10n.of(context)!.start;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: scrolledToTop,
      builder: (context, scrolledToTop, _) => AnimatedSize(
        duration: FluffyThemes.animationDuration,
        curve: FluffyThemes.animationCurve,
        clipBehavior: Clip.none,
        child:
            FloatingActionButton(
                onPressed: () => _onPressed(context),
                child: Icon(icon),
              ),
      ),
    );
  }
}
