import 'package:fluffychat/utils/stream_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:badges/badges.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:keyboard_shortcuts/keyboard_shortcuts.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/navi_rail_item.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/unread_rooms_badge.dart';
import 'package:matrix/matrix.dart';
import '../../widgets/matrix.dart';
import 'chat_list_body.dart';
import 'start_chat_fab.dart';

class DashBoardListViewFactor extends StatelessWidget {
  final DashboardListController controller;

  const DashBoardListViewFactor(this.controller, {super.key});

  List<NavigationDestination> getNavigationDestinations(BuildContext context) {
    final badgePosition = BadgePosition.topEnd(top: -12, end: -8);
    return [
      if (AppConfig.separateChatTypes) ...[
        NavigationDestination(
          icon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.messages),
            child: const Icon(Icons.chat_outlined),
          ),
          selectedIcon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.messages),
            child: const Icon(Icons.chat),
          ),
          label: L10n.of(context)!.messages,
        ),
        NavigationDestination(
          icon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.groups),
            child: const Icon(Icons.group_outlined),
          ),
          selectedIcon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.groups),
            child: const Icon(Icons.group),
          ),
          label: L10n.of(context)!.groups,
        ),
      ] else
        NavigationDestination(
          icon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.allChats),
            child: const Icon(Icons.chat_outlined),
          ),
          selectedIcon: UnreadRoomsBadge(
            badgePosition: badgePosition,
            filter: controller.getRoomFilterByActiveFilter(ActiveFilter.allChats),
            child: const Icon(Icons.chat),
          ),
          label: L10n.of(context)!.chats,
        ),
      if (controller.spaces.isNotEmpty)
        const NavigationDestination(
          icon: Icon(Icons.workspaces_outlined),
          selectedIcon: Icon(Icons.workspaces),
          label: 'Spaces',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    return StreamBuilder<Object?>(
      stream: Matrix.of(context).onShareContentChanged.stream,
      builder: (_, __) {
        final selectMode = controller.selectMode;
        return PopScope(
          canPop: controller.selectMode == SelectMode.normal &&
              !controller.isSearchMode &&
              controller.activeFilter == (AppConfig.separateChatTypes ? ActiveFilter.messages : ActiveFilter.allChats),
          onPopInvoked: (pop) async {
            if (pop) return;
            final selMode = controller.selectMode;
            if (controller.isSearchMode) {
              controller.cancelSearch();
              return;
            }
            if (selMode != SelectMode.normal) {
              return;
            }
            if (controller.activeFilter !=
                (AppConfig.separateChatTypes ? ActiveFilter.messages : ActiveFilter.allChats)) {
              controller.onDestinationSelected(AppConfig.separateChatTypes ? 1 : 0);
              return;
            }
          },
          child: Row(
            children: [

              Expanded(
                child: GestureDetector(
                  onTap: FocusManager.instance.primaryFocus?.unfocus,
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.translucent,
                  child: Scaffold(
                    appBar: AppBar(
                      leading: Center(
                        child:IconButton(
                          onPressed: (){
                            context.go('/dashboard/addToDashboard');
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ),

                    ),
                    body: Dashboard(controller),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () {
                        context.go('/rooms');
                          },
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}






















































class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    return StreamBuilder<Object?>(
      stream: Matrix.of(context).onShareContentChanged.stream,
      builder: (_, __) {
        final selectMode = controller.selectMode;
        return PopScope(
          canPop: controller.selectMode == SelectMode.normal &&
              !controller.isSearchMode &&
              controller.activeSpaceId == null,
          onPopInvoked: (pop) {
            if (pop) return;
            if (controller.activeSpaceId != null) {
              controller.clearActiveSpace();
              return;
            }
            final selMode = controller.selectMode;
            if (controller.isSearchMode) {
              controller.cancelSearch();
              return;
            }
            if (selMode != SelectMode.normal) {
              controller.cancelAction();
              return;
            }
          },
          child: Row(
            children: [
              if (FluffyThemes.isColumnMode(context) &&
                  controller.widget.displayNavigationRail) ...[
                StreamBuilder(
                  key: ValueKey(
                    client.userID.toString(),
                  ),
                  stream: client.onSync.stream
                      .where((s) => s.hasRoomUpdate)
                      .rateLimit(const Duration(seconds: 1)),
                  builder: (context, _) {
                    final allSpaces = Matrix.of(context)
                        .client
                        .rooms
                        .where((room) => room.isSpace);
                    final rootSpaces = allSpaces
                        .where(
                          (space) => !allSpaces.any(
                            (parentSpace) => parentSpace.spaceChildren
                            .any((child) => child.roomId == space.id),
                      ),
                    )
                        .toList();

                    return SizedBox(
                      width: FluffyThemes.navRailWidth,
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: rootSpaces.length + 2,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return NaviRailItem(
                              isSelected: controller.activeSpaceId == null,
                              onTap: controller.clearActiveSpace,
                              icon: const Icon(Icons.forum_outlined),
                              selectedIcon: const Icon(Icons.forum),
                              toolTip: L10n.of(context)!.chats,
                              unreadBadgeFilter: (room) => true,
                            );
                          }
                          i--;
                          if (i == rootSpaces.length) {
                            return NaviRailItem(
                              isSelected: false,
                              onTap: () => context.go('/rooms/newspace'),
                              icon: const Icon(Icons.add),
                              toolTip: L10n.of(context)!.createNewSpace, unreadBadgeFilter: (room) { return false; },
                            );
                          }
                          final space = rootSpaces[i];
                          final displayname =
                          rootSpaces[i].getLocalizedDisplayname(
                            MatrixLocals(L10n.of(context)!),
                          );
                          final spaceChildrenIds =
                          space.spaceChildren.map((c) => c.roomId).toSet();
                          return NaviRailItem(
                            toolTip: displayname,
                            isSelected: controller.activeSpaceId == space.id,
                            onTap: () =>
                                controller.setActiveSpace(rootSpaces[i].id),
                            unreadBadgeFilter: (room) =>
                                spaceChildrenIds.contains(room.id),
                            icon: Avatar(
                              mxContent: rootSpaces[i].avatar,
                              name: displayname,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                Container(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: FocusManager.instance.primaryFocus?.unfocus,
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.translucent,
                  child: Scaffold(
                    body: ChatListViewBody(controller),
                    floatingActionButton: KeyBoardShortcuts(
                      keysToPress: {
                        LogicalKeyboardKey.controlLeft,
                        LogicalKeyboardKey.keyN,
                      },
                      onKeysPressed: () => context.go('/rooms/newprivatechat'),
                      helpLabel: L10n.of(context)!.newChat,
                      child: selectMode == SelectMode.normal &&
                          !controller.isSearchMode
                          ? FloatingActionButton.extended(
                        onPressed: controller.addChatAction,
                        icon: const Icon(Icons.add_outlined),
                        label: Text(
                          L10n.of(context)!.chat,
                          overflow: TextOverflow.fade,
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}