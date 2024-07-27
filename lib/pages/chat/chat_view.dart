import 'dart:async';
import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluffychat/pages/chat/events/audio_player.dart';
import 'package:fluffychat/pages/chat/recording_dialog.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/flutter_matrix_dart_sdk_database/cipher.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_list_tile.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_title.dart';
import 'package:fluffychat/pages/chat/chat_event_list.dart';
import 'package:fluffychat/pages/chat/encryption_button.dart';
import 'package:fluffychat/pages/chat/pinned_events.dart';
import 'package:fluffychat/pages/chat/reactions_picker.dart';
import 'package:fluffychat/pages/chat/reply_display.dart';
import 'package:fluffychat/utils/account_config.dart';
import 'package:fluffychat/widgets/chat_settings_popup_menu.dart';
import 'package:fluffychat/widgets/connection_status_header.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:fluffychat/widgets/unread_rooms_badge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../utils/stream_extension.dart';
import 'chat_emoji_picker.dart';
import 'chat_input_row.dart';

enum _EventContextAction { info, report }

class DashboardView extends StatefulWidget {
  final AudioPageWithDashboardController controller;

  const DashboardView(this.controller, {super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Client sendingClient;
  List<String> _rooms = [];
  Event? replyEvent;
  Duration _duration = Duration.zero;
  Timer? _recorderSubscription;

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
    getTimeline();
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
    print("playing audio");
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

  Future<void> getTimeline({
    String? eventContextId,
  }) async {
    Logs().v('Loading timeline...');
    await Matrix.of(context).client.roomsLoading;
    await Matrix.of(context).client.accountDataLoading;

    final List<Future<Timeline>> roomEvents = _rooms.map((roomId) async {
      final room = Matrix.of(context).client.rooms.firstWhere((element) => element.id == roomId);
      return await room.getTimeline();
    }).toList();

    final timelines = await Future.wait(roomEvents);

    for (final timeline in timelines) {
      if (timeline.events.isNotEmpty) {
        events = timeline.events;
        for (final event in events!) {
          if (event.messageType == "m.audio") {
            print('Audio message');
            _downloadAction(event);
          }
        }
      }
    }
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

  List<Widget> _appBarActions(BuildContext context) {
    if (widget.controller.selectMode) {
      return [
        if (widget.controller.canEditSelectedEvents)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: L10n.of(context)!.edit,
            onPressed: widget.controller.editSelectedEventAction,
          ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: L10n.of(context)!.copy,
          onPressed: widget.controller.copyEventsAction,
        ),
        if (widget.controller.canSaveSelectedEvent)
          // Use builder context to correctly position the share dialog on iPad
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.adaptive.share),
              tooltip: L10n.of(context)!.share,
              onPressed: () => widget.controller.saveSelectedEvent(context),
            ),
          ),
        if (widget.controller.canPinSelectedEvents)
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: widget.controller.pinEvent,
            tooltip: L10n.of(context)!.pinMessage,
          ),
        if (widget.controller.canRedactSelectedEvents)
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            tooltip: L10n.of(context)!.redactMessage,
            onPressed: widget.controller.redactEventsAction,
          ),
        if (widget.controller.selectedEvents.length == 1)
          PopupMenuButton<_EventContextAction>(
            onSelected: (action) {
              switch (action) {
                case _EventContextAction.info:
                  widget.controller.showEventInfo();
                  widget.controller.clearSelectedEvents();
                  break;
                case _EventContextAction.report:
                  widget.controller.reportEventAction();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EventContextAction.info,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context)!.messageInfo),
                  ],
                ),
              ),
              if (widget.controller.selectedEvents.single.status.isSent)
                PopupMenuItem(
                  value: _EventContextAction.report,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(L10n.of(context)!.reportMessage),
                    ],
                  ),
                ),
            ],
          ),
      ];
    } else if (!widget.controller.room.isArchived) {
      return [
        if (Matrix.of(context).voipPlugin != null &&
            widget.controller.room.isDirectChat)
          IconButton(
            onPressed: widget.controller.onPhoneButtonTap,
            icon: const Icon(Icons.call_outlined),
            tooltip: L10n.of(context)!.placeCall,
          ),
        EncryptionButton(widget.controller.room),
        ChatSettingsPopupMenu(widget.controller.room, true),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {


    if (widget.controller.room.membership == Membership.invite) {
      showFutureLoadingDialog(
        context: context,
        future: () => widget.controller.room.join(),
      );
    }

    final bottomSheetPadding = FluffyThemes.isColumnMode(context) ? 16.0 : 8.0;
    final scrollUpBannerEventId = widget.controller.scrollUpBannerEventId;

    final accountConfig = Matrix.of(context).client.applicationAccountConfig;
    final List<Room> publicRooms = [];
    for (var room in _rooms) {
      publicRooms.add(
        Matrix.of(context).client.rooms.firstWhere((element) => element.id == room),
      );
    }
    final List<GetEventsResponse> eventsListResponse = [];
    final client = Matrix.of(context).client;
    final List<Room> eventsList = Matrix.of(context).client.rooms;
    return StreamBuilder(
      stream: widget.controller.room.client.onRoomState.stream
          .where((update) => update.roomId == widget.controller.room.id)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, snapshot) => FutureBuilder(
        future: widget.controller.loadTimelineFuture,
        builder: (BuildContext context, snapshot) {
          var appbarBottomHeight = 0.0;
          if (widget.controller.room.pinnedEventIds.isNotEmpty) {
            appbarBottomHeight += 42;
          }
          if (scrollUpBannerEventId != null) {
            appbarBottomHeight += 42;
          }
          final tombstoneEvent =
              widget.controller.room.getState(EventTypes.RoomTombstone);
          if (tombstoneEvent != null) {
            appbarBottomHeight += 42;
          }
          return GestureDetector(
                    onTapUp: (details) {
                      setState(() {
                        _isRecording = false;
                      });
                      _stopAndSend(widget.controller.room);
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
                            widget.controller.room.displayname,
                            style: Theme.of(context).textTheme.titleLarge,
                          )),
                    ),
                  );
        },
      ),
    );
  }
}




// enum _EventContextAction { info, report }

class ChatView extends StatelessWidget {
  final ChatController controller;

  const ChatView(this.controller, {super.key});

  List<Widget> _appBarActions(BuildContext context) {
    if (controller.selectMode) {
      return [
        if (controller.canEditSelectedEvents)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: L10n.of(context)!.edit,
            onPressed: controller.editSelectedEventAction,
          ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: L10n.of(context)!.copy,
          onPressed: controller.copyEventsAction,
        ),
        if (controller.canSaveSelectedEvent)
        // Use builder context to correctly position the share dialog on iPad
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.adaptive.share),
              tooltip: L10n.of(context)!.share,
              onPressed: () => controller.saveSelectedEvent(context),
            ),
          ),
        if (controller.canPinSelectedEvents)
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: controller.pinEvent,
            tooltip: L10n.of(context)!.pinMessage,
          ),
        if (controller.canRedactSelectedEvents)
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            tooltip: L10n.of(context)!.redactMessage,
            onPressed: controller.redactEventsAction,
          ),
        if (controller.selectedEvents.length == 1)
          PopupMenuButton<_EventContextAction>(
            onSelected: (action) {
              switch (action) {
                case _EventContextAction.info:
                  controller.showEventInfo();
                  controller.clearSelectedEvents();
                  break;
                case _EventContextAction.report:
                  controller.reportEventAction();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EventContextAction.info,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context)!.messageInfo),
                  ],
                ),
              ),
              if (controller.selectedEvents.single.status.isSent)
                PopupMenuItem(
                  value: _EventContextAction.report,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(L10n.of(context)!.reportMessage),
                    ],
                  ),
                ),
            ],
          ),
      ];
    } else if (!controller.room.isArchived) {
      return [
        if (Matrix.of(context).voipPlugin != null &&
            controller.room.isDirectChat)
          IconButton(
            onPressed: controller.onPhoneButtonTap,
            icon: const Icon(Icons.call_outlined),
            tooltip: L10n.of(context)!.placeCall,
          ),
        EncryptionButton(controller.room),
        ChatSettingsPopupMenu(controller.room, true),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (controller.room.membership == Membership.invite) {
      showFutureLoadingDialog(
        context: context,
        future: () => controller.room.join(),
      );
    }
    final bottomSheetPadding = FluffyThemes.isColumnMode(context) ? 16.0 : 8.0;
    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    final accountConfig = Matrix.of(context).client.applicationAccountConfig;

    return PopScope(
      canPop: controller.selectedEvents.isEmpty && !controller.showEmojiPicker,
      onPopInvoked: (pop) async {
        if (pop) return;
        if (controller.selectedEvents.isNotEmpty) {
          controller.clearSelectedEvents();
        } else if (controller.showEmojiPicker) {
          controller.emojiPickerAction();
        }
      },
      child: StreamBuilder(
        stream: controller.room.client.onRoomState.stream
            .where((update) => update.roomId == controller.room.id)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, snapshot) => FutureBuilder(
          future: controller.loadTimelineFuture,
          builder: (BuildContext context, snapshot) {
            var appbarBottomHeight = 0.0;
            if (controller.room.pinnedEventIds.isNotEmpty) {
              appbarBottomHeight += 42;
            }
            if (scrollUpBannerEventId != null) {
              appbarBottomHeight += 42;
            }
            final tombstoneEvent =
            controller.room.getState(EventTypes.RoomTombstone);
            if (tombstoneEvent != null) {
              appbarBottomHeight += 42;
            }
            return Scaffold(
              appBar: AppBar(
                actionsIconTheme: IconThemeData(
                  color: controller.selectedEvents.isEmpty
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                leading: controller.selectMode
                    ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearSelectedEvents,
                  tooltip: L10n.of(context)!.close,
                  color: Theme.of(context).colorScheme.primary,
                )
                    : UnreadRoomsBadge(
                  filter: (r) => r.id != controller.roomId,
                  badgePosition: BadgePosition.topEnd(end: 8, top: 4),
                  child: const Center(child: BackButton()),
                ),
                titleSpacing: 0,
                title: ChatAppBarTitle(controller),
                actions: _appBarActions(context),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(appbarBottomHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PinnedEvents(controller),
                      if (tombstoneEvent != null)
                        ChatAppBarListTile(
                          title: tombstoneEvent.parsedTombstoneContent.body,
                          leading: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.upgrade_outlined),
                          ),
                          trailing: TextButton(
                            onPressed: controller.goToNewRoomAction,
                            child: Text(L10n.of(context)!.goToTheNewRoom),
                          ),
                        ),
                      if (scrollUpBannerEventId != null)
                        ChatAppBarListTile(
                          leading: IconButton(
                            color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            icon: const Icon(Icons.close),
                            tooltip: L10n.of(context)!.close,
                            onPressed: () {
                              controller.discardScrollUpBannerEventId();
                              controller.setReadMarker();
                            },
                          ),
                          title: L10n.of(context)!.jumpToLastReadMessage,
                          trailing: TextButton(
                            onPressed: () {
                              controller.scrollToEventId(
                                scrollUpBannerEventId,
                              );
                              controller.discardScrollUpBannerEventId();
                            },
                            child: Text(L10n.of(context)!.jump),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: controller.showScrollDownButton &&
                  controller.selectedEvents.isEmpty
                  ? Padding(
                padding: const EdgeInsets.only(bottom: 56.0),
                child: FloatingActionButton(
                  onPressed: controller.scrollDown,
                  heroTag: null,
                  mini: true,
                  child: const Icon(Icons.arrow_downward_outlined),
                ),
              )
                  : null,
              body: DropTarget(
                onDragDone: controller.onDragDone,
                onDragEntered: controller.onDragEntered,
                onDragExited: controller.onDragExited,
                child: Stack(
                  children: <Widget>[
                    if (accountConfig.wallpaperUrl != null)
                      Opacity(
                        opacity: accountConfig.wallpaperOpacity ?? 1,
                        child: MxcImage(
                          uri: accountConfig.wallpaperUrl,
                          fit: BoxFit.cover,
                          isThumbnail: true,
                          width: FluffyThemes.columnWidth * 4,
                          height: FluffyThemes.columnWidth * 4,
                          placeholder: (_) => Container(),
                        ),
                      ),
                    SafeArea(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: GestureDetector(
                              onTap: controller.clearSingleSelectedEvent,
                              child: Builder(
                                builder: (context) {
                                  if (controller.timeline == null) {
                                    return const Center(
                                      child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  return ChatEventList(
                                    controller: controller,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (controller.room.canSendDefaultMessages &&
                              controller.room.membership == Membership.join)
                            Container(
                              margin: EdgeInsets.only(
                                bottom: bottomSheetPadding,
                                left: bottomSheetPadding,
                                right: bottomSheetPadding,
                              ),
                              constraints: const BoxConstraints(
                                maxWidth: FluffyThemes.columnWidth * 2.5,
                              ),
                              alignment: Alignment.center,
                              child: Material(
                                clipBehavior: Clip.hardEdge,
                                color: Theme.of(context)
                                    .colorScheme
                                // ignore: deprecated_member_use
                                    .surfaceVariant,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(24),
                                ),
                                child: controller.room.isAbandonedDMRoom == true
                                    ? Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(
                                          16,
                                        ),
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                      icon: const Icon(
                                        Icons.archive_outlined,
                                      ),
                                      onPressed: controller.leaveChat,
                                      label: Text(
                                        L10n.of(context)!.leave,
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.forum_outlined,
                                      ),
                                      onPressed: controller.recreateChat,
                                      label: Text(
                                        L10n.of(context)!.reopenChat,
                                      ),
                                    ),
                                  ],
                                )
                                    : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const ConnectionStatusHeader(),
                                    ReactionsPicker(controller),
                                    ReplyDisplay(controller),
                                    ChatInputRow(controller),
                                    ChatEmojiPicker(controller),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (controller.dragging)
                      Container(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.upload_outlined,
                          size: 100,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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