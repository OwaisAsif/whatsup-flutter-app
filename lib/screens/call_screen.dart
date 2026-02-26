import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whatsup/constants/api_keys.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/firebase/calling_service.dart';
import 'package:whatsup/firebase/chat_service.dart';
import 'package:whatsup/helpers/agora_token_generator.dart';

const String _kAgoraAppId = ApiKeys.kAgoraAppId;
const String _kAgoraAppCertificate = ApiKeys.kAgoraAppCertificate;
const bool _kUseFixedChannelId =
    false; // Toggle to false to fall back to per-call channels.
const String _kFixedAgoraChannelId = 'dev-temp-channel';
const int _kAgoraTokenTtlSeconds = 3600;
const int _kMaxTokenErrorsBeforeRejoin = 3;

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.callType,
    required this.calleeId,
    required this.callerId,
  });

  final String callId;
  final String callType;
  final String calleeId;
  final String callerId;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Map<dynamic, dynamic>? _user;
  bool isLoading = true;
  String _callStatus = 'ringing';
  bool _hasCompleted = false;
  StreamSubscription<DatabaseEvent>? _callSub;
  final loggedInUserId = FirebaseAuth.instance.currentUser?.uid;
  late final DatabaseReference _callRef;
  RtcEngine? _engine;
  bool _engineInitialized = false;
  bool _mediaSessionRequested = false;
  bool _inChannel = false;
  final Set<int> _remoteUids = <int>{};
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _speakerEnabled = true;
  bool _joiningChannel = false;
  String? _activeAgoraToken;
  bool _refreshingToken = false;
  int _tokenErrorCount = 0;

  @override
  void initState() {
    super.initState();
    _callRef = FirebaseDatabase.instance.ref('calls/${widget.callId}');
    _loadPeerProfile();
    _listenToCallStatus();
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _disposeAgora();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  Future<void> _loadPeerProfile() async {
    final peerId = _isCaller ? widget.calleeId : widget.callerId;
    final data = await AuthService.getUserProfile(peerId);
    if (!mounted) return;
    setState(() {
      _user = data;
      isLoading = false;
    });
  }

  void _listenToCallStatus() {
    _callSub = _callRef.onValue.listen((event) {
      final payload = event.snapshot.value as Map<dynamic, dynamic>?;
      if (payload == null) {
        _handleCallTermination('Call ended');
        return;
      }

      final status = (payload['status'] ?? 'ringing').toString();
      if (!mounted) return;
      setState(() {
        _callStatus = status;
      });

      if (status == 'accepted') {
        FlutterRingtonePlayer().stop();
        _startMediaSessionIfNeeded();
      }

      if (status == 'ended' || status == 'rejected') {
        _handleCallTermination(
          'Call ${status == 'rejected' ? 'rejected' : 'ended'}',
        );
      }
    });
  }

  bool get _isCaller => widget.callerId == loggedInUserId;
  bool get _isVideoCall => widget.callType.toLowerCase() == 'video';
  String get _agoraChannelId =>
      _kUseFixedChannelId ? _kFixedAgoraChannelId : widget.callId;

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoCall;
    final isCaller = _isCaller;
    final statusLabel = _statusLabel(isCaller);

    final Widget content = isLoading
        ? const Center(child: CircularProgressIndicator())
        : isVideo && _callStatus == 'accepted'
        ? _buildVideoExperience(statusLabel, isCaller)
        : _buildProfileLayout(isVideo, statusLabel);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(isVideo ? 'Video call' : 'Audio call'),
        centerTitle: true,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildProfileLayout(bool isVideo, String statusLabel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Icon(
            isVideo ? Icons.videocam : Icons.call,
            color: Colors.white,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _user?['username'] ?? 'Unknown',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((_user?['email'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              _user?['email'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildControls(_isCaller, isVideo),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoExperience(String statusLabel, bool isCaller) {
    return Stack(
      children: [
        Positioned.fill(
          child: _engineInitialized && _engine != null && _remoteUids.isNotEmpty
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUids.first),
                    connection: RtcConnection(channelId: _agoraChannelId),
                  ),
                )
              : Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Waiting for ${_user?['username'] ?? 'participant'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
        ),
        if (_engineInitialized && _engine != null)
          Positioned(
            top: 24,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 180,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 24,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user?['username'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statusLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildControls(isCaller, true),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isCaller, bool isVideo) {
    if (!isCaller && _callStatus == 'ringing') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _roundButton(
            context,
            icon: Icons.call_end,
            background: Colors.red,
            iconColor: Colors.white,
            onTap: () => _rejectCall(),
          ),
          const SizedBox(width: 24),
          _roundButton(
            context,
            icon: isVideo ? Icons.videocam : Icons.call,
            background: Colors.green,
            iconColor: Colors.white,
            onTap: () => _acceptCall(),
          ),
        ],
      );
    }

    if (_callStatus != 'accepted') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _roundButton(
            context,
            icon: Icons.call_end,
            background: Colors.red,
            iconColor: Colors.white,
            onTap: () => _endCall(),
          ),
        ],
      );
    }

    final buttons = <Widget>[
      _roundButton(
        context,
        icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
        background: Colors.white24,
        iconColor: Colors.white,
        onTap: _toggleMute,
      ),
      if (isVideo)
        _roundButton(
          context,
          icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
          background: Colors.white24,
          iconColor: Colors.white,
          onTap: _toggleVideo,
        ),
      if (isVideo)
        _roundButton(
          context,
          icon: Icons.cameraswitch,
          background: Colors.white24,
          iconColor: Colors.white,
          onTap: _switchCamera,
        ),
      _roundButton(
        context,
        icon: _speakerEnabled ? Icons.volume_up : Icons.hearing,
        background: Colors.white24,
        iconColor: Colors.white,
        onTap: _toggleSpeaker,
      ),
      _roundButton(
        context,
        icon: Icons.call_end,
        background: Colors.red,
        iconColor: Colors.white,
        onTap: () => _endCall(),
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: buttons,
    );
  }

  Future<void> _acceptCall() async {
    await CallingService.acceptCall(widget.callId);
    _startMediaSessionIfNeeded();
  }

  Future<void> _rejectCall() async {
    await CallingService.rejectCall(widget.callId);
    _handleCallTermination('Call rejected');
  }

  Future<void> _endCall() async {
    await CallingService.endCall(widget.callId);
    if (widget.callerId == loggedInUserId) {
      await ChatService.addCallRecord(widget.callId);
    }
    _handleCallTermination('Call ended');
  }

  void _handleCallTermination(String message) {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _callSub?.cancel();
    _disposeAgora();
    if (!mounted) return;
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    Navigator.of(context).maybePop();
  }

  String _statusLabel(bool isCaller) {
    switch (_callStatus) {
      case 'accepted':
        return 'Call in progress';
      case 'rejected':
        return isCaller ? 'Call rejected' : 'Call declined';
      case 'ended':
        return 'Call ended';
      default:
        return isCaller ? 'Calling...' : 'Incoming call...';
    }
  }

  Future<void> _startMediaSessionIfNeeded() async {
    if (_mediaSessionRequested) return;
    _mediaSessionRequested = true;

    final granted = await _ensurePermissions();
    if (!granted) {
      _mediaSessionRequested = false;
      _showSnack(
        'Microphone${_isVideoCall ? ' & camera' : ''} permission required',
      );
      return;
    }

    try {
      await _initializeAgoraEngine();
      await _joinAgoraChannel();
    } catch (error) {
      _mediaSessionRequested = false;
      debugPrint('Agora init error: $error');
      _showSnack('Unable to start media session');
    }
  }

  Future<bool> _ensurePermissions() async {
    final permissions = <Permission>[Permission.microphone];
    if (_isVideoCall) {
      permissions.add(Permission.camera);
    }

    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  Future<void> _initializeAgoraEngine() async {
    if (_engineInitialized) return;
    if (_kAgoraAppId.isEmpty || _kAgoraAppId == 'YOUR_AGORA_APP_ID') {
      debugPrint('Warning: replace _kAgoraAppId with your Agora App ID');
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(const RtcEngineContext(appId: _kAgoraAppId));
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() {
            _inChannel = true;
          });
          _applySpeakerPreference();
        },
        onLeaveChannel: (connection, stats) {
          if (!mounted) return;
          setState(() {
            _inChannel = false;
            _remoteUids.clear();
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUids.add(remoteUid);
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          setState(() {
            _remoteUids.remove(remoteUid);
          });
        },
        onError: (error, msg) {
          debugPrint('Agora error: $error -> $msg');
          if (error == ErrorCodeType.errTokenExpired) {
            _tokenErrorCount++;
            if (_tokenErrorCount >= _kMaxTokenErrorsBeforeRejoin) {
              _tokenErrorCount = 0;
              unawaited(_forceRejoinWithFreshToken());
            } else {
              _handleTokenRefresh();
            }
          }
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          _handleTokenRefresh();
        },
        onRequestToken: (connection) {
          _handleTokenRefresh();
        },
      ),
    );

    if (_isVideoCall) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.enableAudio();
    }

    _engine = engine;
    _engineInitialized = true;
  }

  Future<void> _joinAgoraChannel() async {
    if (!_engineInitialized || _engine == null) return;
    if (_inChannel) return;

    final options = ChannelMediaOptions(
      channelProfile: ChannelProfileType.channelProfileCommunication,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishCameraTrack: _isVideoCall,
      publishMicrophoneTrack: true,
      autoSubscribeAudio: true,
      autoSubscribeVideo: _isVideoCall,
    );

    if (_joiningChannel || _inChannel) return;

    _joiningChannel = true;
    final token = _buildAgoraToken();

    try {
      await _engine!.joinChannel(
        token: token,
        channelId: _agoraChannelId,
        uid: 0,
        options: options,
      );
    } finally {
      _joiningChannel = false;
    }
  }

  Future<void> _leaveAgoraChannel() async {
    if (!_engineInitialized || _engine == null) return;
    if (_inChannel) {
      try {
        await _engine!.leaveChannel();
      } catch (error) {
        debugPrint('Error leaving Agora channel: $error');
      }
    }
    _inChannel = false;
    _remoteUids.clear();
  }

  Future<void> _disposeAgora() async {
    await _leaveAgoraChannel();
    if (_engine != null) {
      try {
        await _engine!.release();
      } catch (error) {
        debugPrint('Error releasing Agora engine: $error');
      }
    }
    _engine = null;
    _engineInitialized = false;
    _mediaSessionRequested = false;
    _joiningChannel = false;
    _activeAgoraToken = null;
    _refreshingToken = false;
    _tokenErrorCount = 0;
  }

  Future<void> _toggleMute() async {
    if (_engine == null) return;
    final next = !_isAudioMuted;
    await _engine!.muteLocalAudioStream(next);
    setState(() {
      _isAudioMuted = next;
    });
  }

  Future<void> _toggleVideo() async {
    if (!_isVideoCall || _engine == null) return;
    final next = !_isVideoMuted;
    await _engine!.muteLocalVideoStream(next);
    setState(() {
      _isVideoMuted = next;
    });
  }

  Future<void> _switchCamera() async {
    if (!_isVideoCall || _engine == null) return;
    await _engine!.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    if (_engine == null) return;
    final next = !_speakerEnabled;
    try {
      await _engine!.setEnableSpeakerphone(next);
      if (!mounted) {
        _speakerEnabled = next;
        return;
      }
      setState(() {
        _speakerEnabled = next;
      });
    } catch (error) {
      debugPrint('Agora speaker toggle error: $error');
      _showSnack('Unable to switch speaker output');
    }
  }

  Future<void> _applySpeakerPreference() async {
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(_speakerEnabled);
    } catch (error) {
      debugPrint('Agora speakerphone error: $error');
    }
  }

  String _buildAgoraToken() {
    final token = generateToken(
      appId: _kAgoraAppId,
      appCertificate: _kAgoraAppCertificate,
      channelName: _agoraChannelId,
      uid: 0,
      ttlSeconds: _kAgoraTokenTtlSeconds,
    );
    _activeAgoraToken = token;
    return token;
  }

  void _handleTokenRefresh() {
    if (_refreshingToken) {
      return;
    }
    _refreshingToken = true;
    unawaited(_refreshAgoraToken());
  }

  Future<void> _refreshAgoraToken() async {
    if (_engine == null) {
      _refreshingToken = false;
      return;
    }
    final token = _buildAgoraToken();
    try {
      await _engine!.renewToken(token);
      _tokenErrorCount = 0;
    } catch (error) {
      debugPrint('Agora token renew error: $error');
      await _forceRejoinWithFreshToken();
    } finally {
      _refreshingToken = false;
    }
  }

  Future<void> _forceRejoinWithFreshToken() async {
    if (_joiningChannel) return;
    _tokenErrorCount = 0;
    await _leaveAgoraChannel();
    await _joinAgoraChannel();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required Color background,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
