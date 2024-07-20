import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/chat/events/audio_player.dart';
import 'package:fluffychat/pages/chat/recording_dialog.dart';
import 'package:fluffychat/pages/chat_list/chat_list_header.dart';
import 'package:fluffychat/pages/chat_list/search_title.dart';
import 'package:fluffychat/pages/chat_list/status_msg_list.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/flutter_matrix_dart_sdk_database/cipher.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/connection_status_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:matrix/matrix.dart';
import 'package:fluffychat/pages/chat_list/chat_list.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item.dart';
import 'package:fluffychat/pages/chat_list/space_view.dart';
import 'package:fluffychat/pages/chat_list/utils/on_chat_tap.dart';
import 'package:fluffychat/utils/adaptive_bottom_sheet.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/public_room_bottom_sheet.dart';
import 'package:matrix/matrix_api_lite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/themes.dart';
import '../../widgets/hover_builder.dart';
import '../../widgets/matrix.dart';
import '../user_bottom_sheet/user_bottom_sheet.dart';

class Dashboard extends StatefulWidget {
  final DashboardListController controller;

  const Dashboard(this.controller, {super.key});

  @override
  DashboardController createState() => DashboardController();
}

class DashboardController extends State<Dashboard> {
  late Client sendingClient;
  List<String> _rooms = [];
  Event? replyEvent;
  Timer? _recorderSubscription;
  Duration _duration = Duration.zero;

  Timeline? timeline;

  bool error = false;
  String? _recordedPath;
  final _audioRecorder = AudioRecorder();
  final List<double> amplitudeTimeline = [];
  AudioPlayerStatus status = AudioPlayerStatus.notDownloaded;
  AudioPlayer? audioPlayer;

  StreamSubscription? onAudioPositionChanged;
  StreamSubscription? onDurationChanged;
  StreamSubscription? onPlayerStateChanged;
  StreamSubscription? onPlayerError;

  String? statusText;
  int currentPosition = 0;
  double maxPosition = 0;

  MatrixFile? matrixFile;
  File? audioFile;

  static const int bitRate = 64000;
  static const int samplingRate = 44100;
  late List<Event>? events = [];
  bool _isRecording = false;
  @override
  void initState() {
    super.initState();
    sendingClient = Matrix.of(context).client;
    _getTimeline();
    _loadRooms();
  }

  String? scrollToEventIdMarker;
  final AutoScrollController scrollController = AutoScrollController();

  final int _loadHistoryCount = 100;

  void requestFuture() async {
    final timeline = this.timeline;
    if (timeline == null) return;
    if (!timeline.canRequestFuture) return;
    Logs().v('Requesting future...');
    final mostRecentEventId = timeline.events.first.eventId;
    await timeline.requestFuture(historyCount: _loadHistoryCount);
    setReadMarker(eventId: mostRecentEventId);
  }

  Future<void>? loadTimelineFuture;
  void _updateScrollController() {
    if (!mounted) {
      return;
    }
    if (!scrollController.hasClients) return;
    if (timeline?.allowNewEvent == false || scrollController.position.pixels > 0 && _scrolledUp == false) {
      setState(() => _scrolledUp = true);
    } else if (scrollController.position.pixels <= 0 && _scrolledUp == true) {
      setState(() => _scrolledUp = false);
      setReadMarker();
    }

    if (scrollController.position.pixels == 0 || scrollController.position.pixels == 64) {
      requestFuture();
    }
  }

  Future<void> _loadRooms() async {
    final rooms = await UserPreferences.getRooms();
    if (timeline != null && timeline!.events != null) {
      events = timeline!.events;
      print('Events: $events');
    }
    setState(() {
      _rooms = rooms;
    });
  }

  Future<void> _addRoom(String username) async {
    await UserPreferences.addRoom(username);
    _loadRooms();
  }

  Future<void> _updateRoom(int index, String username) async {
    await UserPreferences.updateRoom(index, username);
    _loadRooms();
  }

  Future<void> _deleteRoom(int index) async {
    await UserPreferences.deleteRoom(index);
    _loadRooms();
  }

  Future<void> _clearRooms() async {
    await UserPreferences.clearRooms();
    _loadRooms();
  }

  void voiceMessageAction(Room room, RecordingResult result) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 19) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context)!.unsupportedAndroidVersion,
          message: L10n.of(context)!.unsupportedAndroidVersionLong,
          okLabel: L10n.of(context)!.close,
        );
        return;
      }
    }

    if (await AudioRecorder().hasPermission() == false) return;
    final audioFile = File(result.path);
    final file = MatrixAudioFile(
      bytes: audioFile.readAsBytesSync(),
      name: audioFile.path,
    );
    await room.sendFileEvent(
      file,
      inReplyTo: replyEvent,
      extraContent: {
        'info': {
          ...file.info,
          'duration': result.duration,
        },
        'org.matrix.msc3245.voice': {},
        'org.matrix.msc1767.audio': {
          'duration': result.duration,
          'waveform': result.waveform,
        },
      },
    ).catchError((e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            (e as Object).toLocalizedString(context),
          ),
        ),
      );
      return null;
    });
    setState(() {
      replyEvent = null;
    });
  }

  void _playAction(Event event) async {
    final audioPlayer = this.audioPlayer ??= AudioPlayer();
    if (AudioPlayerWidget.currentId != event.eventId) {
      if (AudioPlayerWidget.currentId != null) {
        if (audioPlayer.playerState.playing) {
          await audioPlayer.stop();
          setState(() {});
        }
      }
      AudioPlayerWidget.currentId = event.eventId;
    }
    if (audioPlayer.playerState.playing) {
      await audioPlayer.pause();
      return;
    } else if (audioPlayer.position != Duration.zero) {
      await audioPlayer.play();
      return;
    }

    onAudioPositionChanged ??= audioPlayer.positionStream.listen((state) {
      if (maxPosition <= 0) return;
      setState(() {
        statusText =
            '${state.inMinutes.toString().padLeft(2, '0')}:${(state.inSeconds % 60).toString().padLeft(2, '0')}';
        currentPosition = ((state.inMilliseconds.toDouble() / maxPosition) * AudioPlayerWidget.wavesCount).round();
      });
      if (state.inMilliseconds.toDouble() == maxPosition) {
        audioPlayer.stop();
        audioPlayer.seek(null);
      }
    });
    onDurationChanged ??= audioPlayer.durationStream.listen((max) {
      if (max == null || max == Duration.zero) return;
      setState(() => maxPosition = max.inMilliseconds.toDouble());
    });
    onPlayerStateChanged ??= audioPlayer.playingStream.listen((_) => setState(() {}));
    final audioFile = this.audioFile;
    if (audioFile != null) {
      audioPlayer.setFilePath(audioFile.path);
    } else {
      await audioPlayer.setAudioSource(MatrixFileAudioSource(matrixFile!));
    }
    audioPlayer.play().onError(
          ErrorReporter(context, 'Unable to play audio message').onErrorCallback,
        );
  }

  void subscribeToRoomStateUpdates() {
    Matrix.of(context)
        .client
        .onRoomState
        .stream
        .where((update) {
          return _rooms.contains(update.roomId);
        })
        .rateLimit(const Duration(seconds: 1))
        .listen((update) {
          print("updated timelines");
          _getTimeline();
        });
    print('Subscribed to room state updates');
  }

  Future<void> startRecording() async {
    setState(() {
      _isRecording = true;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final path = _recordedPath =
          '${tempDir.path}/recording${DateTime.now().microsecondsSinceEpoch}.${RecordingDialog.recordingFileType}';

      final result = await _audioRecorder.hasPermission();
      if (result != true) {
        setState(() => error = true);
        return;
      }
      await WakelockPlus.enable();
      await _audioRecorder.start(
        const RecordConfig(
          bitRate: bitRate,
          sampleRate: samplingRate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      setState(() => _duration = Duration.zero);
      _recorderSubscription?.cancel();
      _recorderSubscription = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        final amplitude = await _audioRecorder.getAmplitude();
        var value = 100 + amplitude.current * 2;
        value = value < 1 ? 1 : value;
        amplitudeTimeline.add(value);
        setState(() {
          _duration += const Duration(milliseconds: 100);
        });
      });
    } catch (_) {
      setState(() => error = true);
      rethrow;
    }
  }

  Future<void>? _setReadMarkerFuture;
  bool _scrolledUp = false;
  String? scrollUpBannerEventId;

  void onInsert(int i) {
    if (timeline?.events[i].status == EventStatus.synced) {
      final index = timeline!.events.firstIndexWhereNotError;
      if (i == index) setReadMarker(eventId: timeline?.events[i].eventId);
    }
  }

  void updateView() {
    if (!mounted) return;
    setState(() {});
  }

  void setReadMarker({String? eventId}) {
    if (_setReadMarkerFuture != null) return;
    if (_scrolledUp) return;
    if (scrollUpBannerEventId != null) return;

    // if (eventId == null && !room.hasNewMessages && room.notificationCount == 0) {
    //   return;
    // }
  }

  Future<void> _downloadAction(Event event) async {
    if (status != AudioPlayerStatus.notDownloaded) return;
    setState(() => status = AudioPlayerStatus.downloading);
    try {
      final matrixFile = await event.downloadAndDecryptAttachment();
      File? file;

      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final fileName = Uri.encodeComponent(
          event.attachmentOrThumbnailMxcUrl()!.pathSegments.last,
        );
        file = File('${tempDir.path}/${fileName}_${matrixFile.name}');
        await file.writeAsBytes(matrixFile.bytes);
      }

      setState(() {
        audioFile = file;
        this.matrixFile = matrixFile;
        status = AudioPlayerStatus.downloaded;
      });
      _playAction(event);
    } catch (e, s) {
      Logs().v('Could not download audio file', e, s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toLocalizedString(context)),
        ),
      );
    }
  }

  Future<void> _getTimeline({
    String? eventContextId,
  }) async {
    Logs().v('Loading timeline...');
    await Matrix.of(context).client.roomsLoading;
    await Matrix.of(context).client.accountDataLoading;
    if (eventContextId != null && (!eventContextId.isValidMatrixId || eventContextId.sigil != '\$')) {
      eventContextId = null;
    }
    final room = Matrix.of(context).client.rooms.firstWhere((element) => element.id == _rooms.first);
    timeline = await room.getTimeline(
      onUpdate: updateView,
      onInsert: onInsert,
    );
    Logs().v('Loaded timeline without event ID ${timeline!.chunk.events.first.eventId}');
    if (timeline?.chunk.events != null) {
      List<Future<Timeline>> roomEvents = _rooms.map((e) async {
        final room = Matrix.of(context).client.rooms.firstWhere((element) => element.id == e);
        return await room.getTimeline(
          onUpdate: updateView,
          onInsert: onInsert,
        );
      }).toList();

      for (var room in roomEvents) {
        final timeline = await room;
        if (timeline.chunk.events != null) {
          events!.addAll(timeline.chunk.events);
        }
      }

      events?.forEach((element) {
        if (element.messageType == 'm.audio') {
          _downloadAction(element);
        }
      });
    }
    timeline!.requestKeys(onlineKeyBackupOnly: false);
    return;
  }

  void _showScrollUpMaterialBanner(String eventId) => setState(() {
        scrollUpBannerEventId = eventId;
      });
  void _stopAndSend(Room room) async {
    _recorderSubscription?.cancel();

    await _audioRecorder.stop();
    await WakelockPlus.disable();
    setState(() {
      _isRecording = false;
    });
    final path = _recordedPath;
    if (path == null) throw ('Recording failed!');
    const waveCount = AudioPlayerWidget.wavesCount;
    final step = amplitudeTimeline.length < waveCount ? 1 : (amplitudeTimeline.length / waveCount).round();
    final waveform = <int>[];
    for (var i = 0; i < amplitudeTimeline.length; i += step) {
      waveform.add((amplitudeTimeline[i] / 100 * 1024).round());
    }
    amplitudeTimeline.clear();
    final RecordingResult result = new RecordingResult(
      path: path,
      duration: _duration.inMilliseconds,
      waveform: waveform,
    );
    // );
    voiceMessageAction(room, result);
  }

  @override
  Widget build(BuildContext context) {
    // subscribeToRoomStateUpdates();
    final List<Room> publicRooms = [];
    for (var room in _rooms) {
      publicRooms.add(
        Matrix.of(context).client.rooms.firstWhere((element) => element.id == room),
      );
    }
    List<GetEventsResponse> eventsListResponse = [];
    final client = Matrix.of(context).client;
    List<Room> eventsList = Matrix.of(context).client.rooms;
    eventsList.forEach((element) async {
      Direction idr = Direction.f;
      // GetRoomEventsResponse eventsListResponse = await client.getRoomEvents(element.id, idr);
      // eventsListResponse.chunk.forEach(
      //   (element) {
      //     print('Event: ${element.type}');
      //
      //   },
      // );
    });

    return PageTransitionSwitcher(
      transitionBuilder: (
        Widget child,
        Animation<double> primaryAnimation,
        Animation<double> secondaryAnimation,
      ) {
        return SharedAxisTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
      },
      child: StreamBuilder(
        key: ValueKey(
          client.userID.toString() +
              widget.controller.activeFilter.toString() +
              widget.controller.activeSpaceId.toString(),
        ),
        stream: Matrix.of(context).client.onRoomState.stream.where((update) {
          return publicRooms.contains(update.roomId);
        }).rateLimit(const Duration(seconds: 1)),
        builder: (context, _) {
          return SafeArea(
            child: CustomScrollView(
              controller: widget.controller.scrollController,
              slivers: [
                // ChatListHeader(controller: controller),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (client.prevBatch != null && _rooms.isEmpty && !widget.controller.isSearchMode) ...[
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Icon(
                            CupertinoIcons.chat_bubble_2,
                            size: 128,
                            color: Theme.of(context).colorScheme.onInverseSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (client.prevBatch != null)
                  SliverList.builder(
                      itemCount: publicRooms.length,
                      itemBuilder: (BuildContext context, int i) {
                        return GestureDetector(
                          onTapUp: (details) {
                            setState(() {
                              _isRecording = false;
                            });
                            _stopAndSend(publicRooms[i]);
                          },
                          onTapDown: (details) {
                            startRecording();
                          },
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                                shape: RoundedRectangleBorder(),
                                subtitle: (_isRecording) ? Text('Recording...') : null,
                                leading: const Icon(Icons.mic),
                                title: Text(
                                  publicRooms[i].displayname,
                                  style: Theme.of(context).textTheme.titleLarge,
                                )),
                          ),
                        );
                      }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ChatListViewBody extends StatelessWidget {
  final ChatListController controller;

  const ChatListViewBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final activeSpace = controller.activeSpaceId;
    if (activeSpace != null) {
      return SpaceView(
        spaceId: activeSpace,
        onBack: controller.clearActiveSpace,
        onChatTab: (room) => controller.onChatTap(room),
        onChatContext: (room, context) => controller.chatContextAction(room, context),
        activeChat: controller.activeChat,
        toParentSpace: controller.setActiveSpace,
      );
    }
    final spaces = client.rooms.where((r) => r.isSpace);
    final spaceDelegateCandidates = <String, Room>{};
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    final publicRooms = controller.roomSearchResult?.chunk.where((room) => room.roomType != 'm.space').toList();
    final publicSpaces = controller.roomSearchResult?.chunk.where((room) => room.roomType == 'm.space').toList();
    final userSearchResult = controller.userSearchResult;
    const dummyChatCount = 4;
    final titleColor = Theme.of(context).textTheme.bodyLarge!.color!.withAlpha(100);
    final subtitleColor = Theme.of(context).textTheme.bodyLarge!.color!.withAlpha(50);
    final filter = controller.searchController.text.toLowerCase();
    return StreamBuilder(
      key: ValueKey(
        client.userID.toString(),
      ),
      stream: client.onSync.stream.where((s) => s.hasRoomUpdate).rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        final rooms = controller.filteredRooms;

        return SafeArea(
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              ChatListHeader(controller: controller),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    if (controller.isSearchMode) ...[
                      SearchTitle(
                        title: L10n.of(context)!.publicRooms,
                        icon: const Icon(Icons.explore_outlined),
                      ),
                      PublicRoomsHorizontalList(publicRooms: publicRooms),
                      SearchTitle(
                        title: L10n.of(context)!.publicSpaces,
                        icon: const Icon(Icons.workspaces_outlined),
                      ),
                      PublicRoomsHorizontalList(publicRooms: publicSpaces),
                      SearchTitle(
                        title: L10n.of(context)!.users,
                        icon: const Icon(Icons.group_outlined),
                      ),
                      AnimatedContainer(
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        height: userSearchResult == null || userSearchResult.results.isEmpty ? 0 : 106,
                        duration: FluffyThemes.animationDuration,
                        curve: FluffyThemes.animationCurve,
                        child: userSearchResult == null
                            ? null
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: userSearchResult.results.length,
                                itemBuilder: (context, i) => _SearchItem(
                                  title: userSearchResult.results[i].displayName ??
                                      userSearchResult.results[i].userId.localpart ??
                                      L10n.of(context)!.unknownDevice,
                                  avatar: userSearchResult.results[i].avatarUrl,
                                  onPressed: () => showAdaptiveBottomSheet(
                                    context: context,
                                    builder: (c) => UserBottomSheet(
                                      profile: userSearchResult.results[i],
                                      outerContext: context,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                    if (!controller.isSearchMode && AppConfig.showPresences)
                      GestureDetector(
                        onLongPress: () => controller.dismissStatusList(),
                        child: StatusMessageList(
                          onStatusEdit: controller.setStatus,
                        ),
                      ),
                    const ConnectionStatusHeader(),
                    AnimatedContainer(
                      height: controller.isTorBrowser ? 64 : 0,
                      duration: FluffyThemes.animationDuration,
                      curve: FluffyThemes.animationCurve,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: ListTile(
                          leading: const Icon(Icons.vpn_key),
                          title: Text(L10n.of(context)!.dehydrateTor),
                          subtitle: Text(L10n.of(context)!.dehydrateTorLong),
                          trailing: const Icon(Icons.chevron_right_outlined),
                          onTap: controller.dehydrate,
                        ),
                      ),
                    ),
                    if (client.rooms.isNotEmpty && !controller.isSearchMode)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6,
                          ),
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          children: [
                            ActiveFilter.allChats,
                            ActiveFilter.unread,
                            ActiveFilter.groups,
                            if (spaceDelegateCandidates.isNotEmpty && !controller.widget.displayNavigationRail)
                              ActiveFilter.spaces,
                          ]
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: HoverBuilder(
                                    builder: (context, hovered) => AnimatedScale(
                                      duration: FluffyThemes.animationDuration,
                                      curve: FluffyThemes.animationCurve,
                                      scale: hovered ? 1.1 : 1.0,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          AppConfig.borderRadius,
                                        ),
                                        onTap: () => controller.setActiveFilter(filter),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: filter == controller.activeFilter
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              AppConfig.borderRadius,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            filter.toLocalizedString(context),
                                            style: TextStyle(
                                              fontWeight: filter == controller.activeFilter
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: filter == controller.activeFilter
                                                  ? Theme.of(context).colorScheme.onPrimary
                                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (controller.isSearchMode)
                      SearchTitle(
                        title: L10n.of(context)!.chats,
                        icon: const Icon(Icons.forum_outlined),
                      ),
                    if (client.prevBatch != null && rooms.isEmpty && !controller.isSearchMode) ...[
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Icon(
                          CupertinoIcons.chat_bubble_2,
                          size: 128,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (client.prevBatch == null)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Opacity(
                      opacity: (dummyChatCount - i) / dummyChatCount,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: titleColor,
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: titleColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                            Container(
                              height: 14,
                              width: 14,
                              decoration: BoxDecoration(
                                color: subtitleColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 14,
                              width: 14,
                              decoration: BoxDecoration(
                                color: subtitleColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Container(
                          decoration: BoxDecoration(
                            color: subtitleColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          height: 12,
                          margin: const EdgeInsets.only(right: 22),
                        ),
                      ),
                    ),
                    childCount: dummyChatCount,
                  ),
                ),
              if (client.prevBatch != null)
                SliverList.builder(
                  itemCount: rooms.length,
                  itemBuilder: (BuildContext context, int i) {
                    final room = rooms[i];
                    final space = spaceDelegateCandidates[room.id];
                    return ChatListItem(
                      room,
                      space: space,
                      key: Key('chat_list_item_${room.id}'),
                      filter: filter,
                      onTap: () => controller.onChatTap(room),
                      onLongPress: (context) => controller.chatContextAction(room, context, space),
                      activeChat: controller.activeChat == room.id,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class PublicRoomsHorizontalList extends StatelessWidget {
  const PublicRoomsHorizontalList({
    super.key,
    required this.publicRooms,
  });

  final List<PublicRoomsChunk>? publicRooms;

  @override
  Widget build(BuildContext context) {
    final publicRooms = this.publicRooms;
    return AnimatedContainer(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      height: publicRooms == null || publicRooms.isEmpty ? 0 : 106,
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      child: publicRooms == null
          ? null
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: publicRooms.length,
              itemBuilder: (context, i) => _SearchItem(
                title: publicRooms[i].name ?? publicRooms[i].canonicalAlias?.localpart ?? L10n.of(context)!.group,
                avatar: publicRooms[i].avatarUrl,
                onPressed: () => showAdaptiveBottomSheet(
                  context: context,
                  builder: (c) => PublicRoomBottomSheet(
                    roomAlias: publicRooms[i].canonicalAlias ?? publicRooms[i].roomId,
                    outerContext: context,
                    chunk: publicRooms[i],
                  ),
                ),
              ),
            ),
    );
  }
}

extension on List<Event> {
  int get firstIndexWhereNotError {
    if (isEmpty) return 0;
    final index = indexWhere((event) => !event.status.isError);
    if (index == -1) return length;
    return index;
  }
}

class _SearchItem extends StatelessWidget {
  final String title;
  final Uri? avatar;
  final void Function() onPressed;

  const _SearchItem({
    required this.title,
    this.avatar,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Avatar(
                mxContent: avatar,
                name: title,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
