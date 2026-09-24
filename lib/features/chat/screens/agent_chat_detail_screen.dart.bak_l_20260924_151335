import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/services/agent_realtime_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';
import 'package:vpn_agent_app/core/utils/formatters.dart';
import 'package:vpn_agent_app/core/widgets/confirm_dialog.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/chat/services/agent_chat_service.dart';

class AgentChatDetailScreen extends StatefulWidget {
  final int userId;
  final String username;

  const AgentChatDetailScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<AgentChatDetailScreen> createState() => _AgentChatDetailScreenState();
}

class _AgentChatDetailScreenState extends State<AgentChatDetailScreen> {
  final _chatService = AgentChatService();
  final _msgController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _userInfo;
  List<Map<String, dynamic>> _messages = [];
  File? _selectedImage;

  bool _loading = true;

  /// HISTORY_FAILURE_STATE_V1 — the history request came back with nothing
  /// and the thread is empty. Not the same as a conversation not yet started.
  bool _failed = false;
  bool _showJumpToLatest = false;
  double _lastKeyboardInset = 0;

  /// Typing indicator, expired locally. There is no "stopped typing" event —
  /// an app closed mid-sentence would never send one — so the dots time out
  /// a few seconds after the last signal instead.
  bool _userTyping = false;
  Timer? _typingTimer;

  /// CHAT_FAST_DECISION_STATE_V1 — req_id -> 'approved' / 'rejected' for the
  /// decisions made in this thread, drawn before the server has been told.
  ///
  /// A message is a Map here rather than a model, so the decision could in
  /// principle be written onto the row; it is kept separate anyway because
  /// _loadMessages(silent: true) replaces the whole list with the server's
  /// copy, and that copy still carries the buttons until the backend has
  /// processed the request. The map survives the reload, the row does not.
  ///
  /// Cleared for one id only, when its POST fails and the buttons must return.
  final Map<int, String> _localDecisions = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Focusing the field shrinks the viewport by the keyboard's height. The
    // list keeps its scroll offset, so the newest message slides out of sight
    // and the agent has to drag down to see what they are replying to.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom();
    });

    // No polling timer. Every message this thread can receive is broadcast:
    // the user's own (ChatController), the agent's replies including those
    // sent from another device (AgentChatController::reply), and the AI's
    // (AiChatController). The old screen refetched the whole history every 6
    // seconds — roughly 600 requests an hour with a chat left open — because
    // its socket handler discarded everything that was not sender_type 'user'.
    AgentRealtimeService.instance.start();
    AgentRealtimeService.instance.addListener(_onRealtimeMessage);
    AgentRealtimeService.instance.addReadListener(_onRead);
    AgentRealtimeService.instance.addTypingListener(_onTyping);

    _loadMessages();
  }

  @override
  void dispose() {
    AgentRealtimeService.instance.removeListener(_onRealtimeMessage);
    AgentRealtimeService.instance.removeReadListener(_onRead);
    AgentRealtimeService.instance.removeTypingListener(_onTyping);
    _typingTimer?.cancel();
    _msgController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ──────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show =
        _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 250;
    if (show != _showJumpToLatest) setState(() => _showJumpToLatest = show);
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150;
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  // ── Data ────────────────────────────────────────────────────────────────

  void _onRealtimeMessage(Map<String, dynamic> msg) {
    if (!mounted) return;

    final raw = msg['vpn_user_id'];
    final userId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (userId != widget.userId) return;

    // Every sender is rendered, not just the user. Agent replies from another
    // device and AI answers arrive on this channel too; ignoring them was what
    // made the 6-second poll necessary.
    final id = msg['id'];
    if (id != null && _messages.any((m) => m['id'] == id)) return;

    // An optimistic copy of this same reply may still be on screen. Matched on
    // text and sender so the real row replaces it rather than doubling it.
    final text = (msg['message'] ?? '').toString();
    if (msg['sender_type'] == 'admin' && text.isNotEmpty) {
      final pending = _messages.indexWhere(
        (m) => m['_sending'] == true && (m['message'] ?? '') == text,
      );
      if (pending != -1) {
        setState(() => _messages[pending] = Map<String, dynamic>.from(msg));
        return;
      }
    }

    final atBottom = _isAtBottom;
    setState(() => _messages.add(Map<String, dynamic>.from(msg)));
    if (atBottom) _scrollToBottom();
  }

  void _onRead(Map<String, dynamic> data) {
    if (!mounted) return;
    if (_idOf(data['vpn_user_id']) != widget.userId) return;

    // up_to_id bounds the range when the client reported one; without it the
    // user opened the thread, which means everything sent so far is read.
    final upTo = _idOf(data['up_to_id']);

    setState(() {
      for (final m in _messages) {
        if (m['sender_type'] != 'admin') continue;
        if (m['is_read'] == true) continue;
        final id = _idOf(m['id']);
        if (upTo != null && id != null && id > upTo) continue;
        m['is_read'] = true;
      }
    });
  }

  void _onTyping(Map<String, dynamic> data) {
    if (!mounted) return;
    if (_idOf(data['vpn_user_id']) != widget.userId) return;

    final wasAtBottom = _isNearBottom;
    if (!_userTyping) setState(() => _userTyping = true);

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _userTyping = false);
    });

    if (wasAtBottom) _scrollToBottom();
  }

  static int? _idOf(dynamic raw) =>
      raw is int ? raw : int.tryParse(raw?.toString() ?? '');

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final result = await _chatService.getHistory(widget.userId);
    if (!mounted) return;

    if (result == null) {
      // A silent reload that fails leaves the thread alone; only an empty
      // screen reports it, and then with a retry rather than "no messages
      // yet", which reads as a conversation nobody has started.
      setState(() {
        _failed = _messages.isEmpty;
        _loading = false;
      });
      return;
    }

    final atBottom = _isAtBottom;
    setState(() {
      _failed = false;
      _userInfo = result['user'] != null
          ? Map<String, dynamic>.from(result['user'])
          : null;
      _messages =
          (result['messages'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      _loading = false;
    });

    if (!silent || atBottom) _scrollToBottom(animate: silent);
  }

  // ── Sending ─────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _msgController.text.trim();
    final image = _selectedImage;
    if (text.isEmpty && image == null) return;

    _msgController.clear();
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _selectedImage = null;
      _messages.add({
        'id': tempId,
        'sender_type': 'admin',
        'message': text,
        'image_url': image?.path,
        'type': 'text',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        '_sending': true,
        '_is_local_image': image != null,
      });
    });
    _scrollToBottom();

    try {
      final result = await _chatService.sendReply(
        widget.userId,
        message: text,
        image: image,
      );
      if (!mounted) return;

      if (result == null || result['success'] == false) {
        // A failed message is kept and flagged rather than removed, so the
        // agent can see what did not go and copy the text back out.
        setState(() {
          final i = _messages.indexWhere((m) => m['id'] == tempId);
          if (i != -1) {
            _messages[i]['_sending'] = false;
            _messages[i]['_failed'] = true;
          }
        });
        _toast('Message not sent.');
        return;
      }

      // The broadcast usually lands first and swaps the optimistic copy for
      // the real row. This clears the spinner if it has not.
      setState(() {
        final i = _messages.indexWhere((m) => m['id'] == tempId);
        if (i == -1) return;
        final real = result['data'];
        _messages[i] = real is Map
            ? Map<String, dynamic>.from(real)
            : {..._messages[i], '_sending': false};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m['id'] == tempId);
        if (i != -1) {
          _messages[i]['_sending'] = false;
          _messages[i]['_failed'] = true;
        }
      });
      _toast('Network error. Message not sent.');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        _toast('Could not open the gallery. Check the app permissions.');
      }
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _sendPlanCard() async {
    final ok = await _confirm(
      title: 'Send plan options?',
      body:
          '${widget.username} will see the available plans and can renew '
          'straight from the message.',
      actionLabel: 'Send',
      actionColor: AppColors.accentInk,
    );
    if (ok != true) return;

    await _runGuarded(() async {
      final sent = await _chatService.sendPlanCard(widget.userId);
      if (!mounted) return;
      // SEND_PLAN_CARD_RESULT_V1 — null is the transport failing; a body
      // carrying success false is the server refusing. Only the first was
      // handled, so a refusal left the agent watching a thread with no plan
      // card in it and nothing said about why.
      if (sent == null || sent['success'] == false) {
        AppLog.e('sendPlanCard', sent?['message'] ?? 'no response');
        _toast('အစီအစဉ်စာရင်း ပို့၍ မရပါ။ ထပ်မံ ကြိုးစားပါ။');
        return;
      }
      _loadMessages(silent: true);
    });
  }

  Future<void> _openExtendSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExtendSheet(
        username: widget.username,
        planPrice:
            int.tryParse(_userInfo?['plan_price']?.toString() ?? '0') ?? 0,
      ),
    );
    if (result == null || !mounted) return;

    await _runGuarded(() async {
      final response = await _chatService.extendSubscription(
        widget.userId,
        result['months'] as int,
        result['days'] as int,
      );
      if (!mounted) return;

      _toast(
        response?['message']?.toString() ??
            (response == null ? 'Could not extend.' : 'Subscription extended.'),
      );
      _loadMessages(silent: true);
    });
  }

  /// APPROVE_SHOWS_COST_V1 — the dialog names who, what and how much.
  ///
  /// It used to say "Credit will be deducted from your balance" and nothing
  /// else: no user, no plan, no number. [meta] is the renewal message's own
  /// metadata, which is where those three facts already are.
  Future<void> _approve(int reqId, Map<String, dynamic> meta) async {
    // CHAT_APPROVE_REENTRY_V1 — the modal barrier used to make a second tap
    // impossible. The bubble losing its buttons does the same job now, but
    // the retry action on the failure snackbar calls back in here directly.
    if (_localDecisions.containsKey(reqId)) return;

    final cost = _idOf(meta['estimated_cost']) ?? 0;
    final planName = (meta['plan_name'] ?? '').toString();
    final months = _idOf(meta['duration_months']) ?? 0;

    final confirmed = await confirmAction(
      context,
      title: 'တောင်းဆိုမှုကို အတည်ပြုမလား',
      message: 'အတည်ပြုပါက အောက်ပါပမာဏကို သင့် Credit မှ ချက်ချင်း နုတ်ယူပါမည်။',
      details: [
        ConfirmDetail('အသုံးပြုသူ', widget.username),
        ConfirmDetail(
          'အစီအစဉ်',
          planName.isEmpty ? 'အစီအစဉ် မသိရပါ' : '$planName · $months လ',
        ),
        ConfirmDetail(
          'ကုန်ကျမည့် Credit',
          // The backend computes this; an older payload may not carry it, and
          // a confident "0 MMK" would be worse than saying so.
          cost > 0
              ? '${Fmt.money.format(cost)} MMK'
              : 'အတည်ပြုချိန်တွင် တွက်ချက်ပါမည်',
          emphasise: true,
        ),
      ],
    );
    if (!confirmed || !mounted) return;

    // CHAT_FAST_APPROVE_V1 — the bubble changes here, before the POST.
    //
    // _runGuarded put a PopScope spinner over the whole screen and held it
    // for the length of the call, then a silent history reload followed. The
    // barrier is off this path: the decision is drawn at once and the call
    // runs behind it. _runGuarded stays for _sendPlanCard and the extend
    // sheet, which both change the thread wholesale on a figure the agent
    // typed and have nothing to show until they return.
    setState(() => _localDecisions[reqId] = 'approved');
    _toast('${widget.username} ၏ တောင်းဆိုမှုကို အတည်ပြုလိုက်ပါပြီ။');

    await _settleDecision(
      reqId,
      'approved',
      () => _chatService.approveRequest(reqId),
      '${widget.username} ၏ တောင်းဆိုမှုကို အတည်မပြုနိုင်ပါ။ '
          'တောင်းဆိုမှုကို ပြန်လည် ပြသထားပါသည်။ Credit လက်ကျန်နှင့် '
          'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
      () => _approve(reqId, meta),
    );
  }

  Future<void> _reject(int reqId) async {
    // CHAT_FAST_REJECT_V1 — same shape as approve, and the confirmation is
    // Burmese now: it is on a path this change rewrites and it names the user.
    if (_localDecisions.containsKey(reqId)) return;

    final ok = await _confirm(
      title: 'တောင်းဆိုမှုကို ငြင်းပယ်မလား',
      body: '${widget.username} ထံသို့ အတည်မပြုကြောင်း အကြောင်းကြားပါမည်။',
      actionLabel: 'ငြင်းပယ်မည်',
      actionColor: AppColors.danger,
    );
    if (ok != true || !mounted) return;

    setState(() => _localDecisions[reqId] = 'rejected');
    _toast('${widget.username} ၏ တောင်းဆိုမှုကို ငြင်းပယ်လိုက်ပါပြီ။');

    await _settleDecision(
      reqId,
      'rejected',
      () => _chatService.rejectRequest(reqId),
      '${widget.username} ၏ တောင်းဆိုမှုကို ငြင်းပယ်၍ မရပါ။ '
          'တောင်းဆိုမှုကို ပြန်လည် ပြသထားပါသည်။ အင်တာနက် ချိတ်ဆက်မှုကို '
          'စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
      () => _reject(reqId),
    );
  }

  /// CHAT_SETTLE_DECISION_V1 — runs the POST behind a decision already drawn.
  ///
  /// Nothing waits on this; the tap returned when the bubble changed. So it
  /// catches everything, logs through AppLog.e, and finishes either quietly
  /// (a silent history reload, so the thread picks up the server's own system
  /// message) or loudly. It cannot finish without doing one of the two.
  Future<void> _settleDecision(
    int reqId,
    String decision,
    Future<Map<String, dynamic>> Function() send,
    String failureMessage,
    VoidCallback onRetry,
  ) async {
    Map<String, dynamic>? result;
    try {
      result = await send();
    } catch (error) {
      AppLog.e('chatDecision/$decision', error);
    }
    if (!mounted) return;

    if (result != null && result['success'] != false) {
      // Silent: no spinner, no second toast. The acknowledgement was shown at
      // the tap, and _localDecisions keeps the bubble decided even though the
      // reloaded copy of the message still carries its buttons.
      _loadMessages(silent: true);
      return;
    }

    AppLog.e(
      'chatDecision/$decision',
      result?['message'] ?? 'request $reqId was not applied',
    );
    setState(() => _localDecisions.remove(reqId));
    _decisionFailed(failureMessage, onRetry);
  }

  /// A decision that never reached the server.
  ///
  /// The bubble has already been restored by the caller. Red, eight seconds
  /// rather than the default four, the user's name in the text, and the retry
  /// on the snackbar itself — a bubble whose buttons quietly came back would
  /// read as a tap that never registered.
  void _decisionFailed(String message, VoidCallback onRetry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textOnAccent),
          ),
          action: SnackBarAction(
            label: 'ထပ်မံကြိုးစားမည်',
            textColor: AppColors.textOnAccent,
            onPressed: onRetry,
          ),
        ),
      );
  }

  /// MONEY_SAFETY_V1 — one action at a time, with the screen blocked.
  ///
  /// Extend and the plan card both change the thread wholesale and neither
  /// disabled anything while it was in flight: a slow network showed no change
  /// on screen, the agent tapped again, and the second POST went out. The
  /// barrier stops the tap and says the work is running.
  ///
  /// Approve and reject no longer come through here. They have something to
  /// show the moment they are tapped, so blocking the screen behind a spinner
  /// bought nothing but the wait.
  bool _actionBusy = false;

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_actionBusy) return;
    _actionBusy = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );

    try {
      await action();
    } finally {
      _actionBusy = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          // CONFIRM_TAP_TARGET_44_V1 — the Material default is 40dp high,
          // under the minimum, on a dialog whose confirm button can be
          // destructive. minimumSize only: same padding, same type, same
          // colours. The cancel label matches confirm_dialog.dart, which is
          // what the rest of this screen's confirmations use.
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('မလုပ်တော့ပါ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: actionColor,
              minimumSize: const Size(64, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openImage(String url, {bool isLocal = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(url: url, isLocal: isLocal),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // The focus listener fires before the keyboard animation reports its
    // height, so the first scroll lands short. This runs on the inset change
    // itself, which is the point the viewport is its final size.
    final inset = MediaQuery.of(context).viewInsets.bottom;
    if (inset > 0 && inset != _lastKeyboardInset && _isNearBottom) {
      _scrollToBottom(animate: false);
    }
    _lastKeyboardInset = inset;
  }

  /// Slacker than _isAtBottom: after a send the offset can be a few hundred
  /// pixels off while the new bubble lays out, and that still counts as
  /// "reading the end of the thread".
  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _userInfo?['is_online'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(username: widget.username, isOnline: isOnline, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      if (isOnline) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          isOnline
                              ? 'Online'
                              : _lastSeen(_userInfo?['last_seen']?.toString()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isOnline
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Extend is the money action and stays a button; the rest go behind
          // a menu, so the bar does not turn into a row of glyphs an agent has
          // to decode mid-conversation.
          IconButton(
            onPressed: _openExtendSheet,
            icon: const Icon(Iconsax.clock, size: 20),
            tooltip: 'Extend subscription',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'plan') _sendPlanCard();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'plan',
                child: Row(
                  children: [
                    Icon(Iconsax.card, size: 17),
                    SizedBox(width: 10),
                    Text('Send plan options'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_userInfo != null) _UserInfoBar(info: _userInfo!),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _messages.isEmpty
                ? (_failed
                      ? AppEmptyState(
                          icon: Iconsax.cloud_cross,
                          title: 'စာများ ဆွဲယူ၍ မရပါ',
                          subtitle:
                              'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
                          actionLabel: 'ထပ်မံကြိုးစားမည်',
                          onAction: () => _loadMessages(),
                        )
                      : const AppEmptyState(
                          icon: Iconsax.message_text,
                          title: 'No messages yet',
                          subtitle: 'Anything you send appears here.',
                        ))
                : Stack(
                    children: [
                      // Tapping the thread dismisses the keyboard. Without it
                      // the only way out is the system back gesture, which on
                      // Android also risks leaving the screen.
                      GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.opaque,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _messages.length + (_userTyping ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _messages.length) {
                              return const _TypingBubble();
                            }
                            final msg = _messages[i];
                            final prev = i > 0 ? _messages[i - 1] : null;
                            final next = i + 1 < _messages.length
                                ? _messages[i + 1]
                                : null;
                            // CHAT_BUBBLE_DECISION_V1 — null for every message
                            // that is not a renewal request, and for a renewal
                            // this agent has not decided on this device.
                            final reqId = msg['req_id'];
                            return _MessageBubble(
                              msg: msg,
                              renewalDecision: reqId is int
                                  ? _localDecisions[reqId]
                                  : null,
                              // Consecutive messages from one sender are drawn
                              // as a run: only the last keeps a tail and a
                              // timestamp. A column of identical bubbles each
                              // with its own time reads as noise.
                              isFirstInRun: _startsRun(prev, msg),
                              isLastInRun: _startsRun(msg, next),
                              // A date separator whenever the day changes, so a
                              // thread months long can be placed in time without
                              // opening each timestamp.
                              showDaySeparator: _isNewDay(prev, msg),
                              onApprove: _approve,
                              onReject: _reject,
                              onOpenImage: _openImage,
                            );
                          },
                        ),
                      ),
                      if (_showJumpToLatest)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: 'jump-latest',
                            onPressed: () => _scrollToBottom(),
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textSecondary,
                            elevation: 2,
                            shape: const CircleBorder(
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _Composer(
            controller: _msgController,
            focusNode: _focusNode,
            selectedImage: _selectedImage,
            onPickImage: _pickImage,
            onClearImage: () => setState(() => _selectedImage = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }

  /// True when [msg] begins a new run — a different sender from [prev], or
  /// more than five minutes later.
  static bool _startsRun(
    Map<String, dynamic>? prev,
    Map<String, dynamic>? msg,
  ) {
    if (prev == null || msg == null) return true;
    if (prev['sender_type'] != msg['sender_type']) return true;
    if ((prev['type'] ?? 'text') != 'text' ||
        (msg['type'] ?? 'text') != 'text') {
      return true;
    }
    final a = DateTime.tryParse((prev['created_at'] ?? '').toString());
    final b = DateTime.tryParse((msg['created_at'] ?? '').toString());
    if (a == null || b == null) return true;
    return b.difference(a).inMinutes.abs() > 5;
  }

  static bool _isNewDay(Map<String, dynamic>? prev, Map<String, dynamic> msg) {
    final current = DateTime.tryParse((msg['created_at'] ?? '').toString());
    if (current == null) return false;
    if (prev == null) return true;
    final previous = DateTime.tryParse((prev['created_at'] ?? '').toString());
    if (previous == null) return true;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  static String _lastSeen(String? raw) {
    if (raw == null || raw.isEmpty) return 'Offline';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Offline';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${Fmt.dayMonth.format(parsed)}';
  }
}

/// Who this user is, at a glance, above the thread.
///
/// The agent answering a message needs the same facts every time — which
/// agent owns the account, what they are on, when it lapses, how many devices
/// — and was otherwise switching to the user list and back to find them. Every
/// field here is already in the history payload; none of it costs a request.
class _UserInfoBar extends StatelessWidget {
  final Map<String, dynamic> info;

  const _UserInfoBar({required this.info});

  @override
  Widget build(BuildContext context) {
    final expiryLabel = (info['expiry_label'] ?? '').toString();
    final expiryDays = info['expiry_days'];
    final expiryColor = switch (expiryDays) {
      null => AppColors.neutral,
      final int d when d < 0 => AppColors.danger,
      final int d when d <= 7 => AppColors.warning,
      _ => AppColors.success,
    };

    final chips = <Widget>[
      if (expiryLabel.isNotEmpty)
        _InfoChip(
          icon: Iconsax.timer_1,
          label: expiryLabel,
          color: expiryColor,
          detail: _formatExpiry(info['expiry_date']?.toString()),
        ),
      if ((info['plan_name'] ?? '').toString().isNotEmpty)
        _InfoChip(
          icon: Iconsax.crown_1,
          label: info['plan_name'].toString(),
          color: AppColors.accentInk,
        ),
      if ((info['business_plan'] ?? '').toString().isNotEmpty)
        _InfoChip(
          icon: Iconsax.briefcase,
          label: info['business_plan'].toString(),
          color: AppColors.orange,
        ),
      if ((info['server_name'] ?? '').toString().isNotEmpty)
        _InfoChip(
          icon: Iconsax.global,
          label: info['server_name'].toString(),
          color: AppColors.info,
        ),
      _InfoChip(
        icon: Iconsax.mobile,
        label:
            '${info['devices'] ?? 1} device${(info['devices'] ?? 1) == 1 ? '' : 's'}',
        color: AppColors.violet,
      ),
      if ((info['traffic_used'] ?? '').toString().isNotEmpty)
        _InfoChip(
          icon: Iconsax.chart_2,
          label: info['traffic_used'].toString(),
          color: AppColors.cyan,
          detail:
              'Used ${info['traffic_used']} of '
              '${info['traffic_limit'] ?? 'Unlimited'}',
        ),
      if ((info['app_version'] ?? '').toString().isNotEmpty)
        _InfoChip(
          // Platform as an icon rather than a word: it is the difference
          // between "update from the Play Store" and "from the App Store",
          // and a glyph reads faster than "android" spelled out.
          icon: _platformIcon(info['platform']?.toString()),
          label: info['app_version'].toString(),
          color: AppColors.textSecondary,
          detail: [
            info['device_name'],
            info['platform'],
            info['app_version'],
          ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
        ),
      if ((info['agent_name'] ?? '').toString().isNotEmpty)
        _InfoChip(
          icon: Iconsax.user_octagon,
          label: info['agent_name'].toString(),
          color: AppColors.neutral,
        ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      // Horizontal rather than wrapped: the bar must not grow to three lines
      // on a user with a business plan and a long server name, and eat the
      // thread it sits above.
      child: SizedBox(
        height: 26,
        // Faded at the right edge: without it a row that scrolls looks like a
        // row that has been cut off.
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.9, 1.0],
            colors: [Colors.black, Colors.black, Colors.transparent],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
      ),
    );
  }

  /// Only recent builds report a platform, so an unknown one still gets a
  /// generic device glyph rather than nothing.
  static IconData _platformIcon(String? platform) =>
      switch (platform?.toLowerCase()) {
        'ios' => Icons.apple,
        'macos' => Icons.laptop_mac,
        'android' => Icons.android,
        'windows' => Icons.desktop_windows,
        _ => Iconsax.mobile,
      };

  static String? _formatExpiry(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    // FMT_DATE_V1 — one DateFormat for the app, built on first use. This one
    // was constructed for every chip built, on every rebuild of the info bar.
    return Fmt.date.format(parsed);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// Shown on tap. Keeps the chip short while the exact date or figure stays
  /// reachable.
  final String? detail;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (detail == null) return chip;

    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail!), duration: const Duration(seconds: 2)),
      ),
      child: chip,
    );
  }
}

// ── Bubbles ───────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool showDaySeparator;
  final bool isFirstInRun;
  final bool isLastInRun;

  /// BUBBLE_DECISION_FIELD_V1 — 'approved', 'rejected', or null when this
  /// agent has made no decision on this request on this device. Only a
  /// renewal bubble reads it.
  final String? renewalDecision;

  final Future<void> Function(int, Map<String, dynamic>) onApprove;
  final Future<void> Function(int) onReject;
  final void Function(String, {bool isLocal}) onOpenImage;

  const _MessageBubble({
    required this.msg,
    required this.showDaySeparator,
    this.isFirstInRun = true,
    this.isLastInRun = true,
    this.renewalDecision,
    required this.onApprove,
    required this.onReject,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final type = (msg['type'] ?? 'text').toString();

    final body = switch (type) {
      // BUBBLE_DECISION_PASS_V1 — the only bubble that can be decided.
      'renewal_request' => _RenewalBubble(
        msg: msg,
        decision: renewalDecision,
        onApprove: onApprove,
        onReject: onReject,
        onOpenImage: onOpenImage,
      ),
      'plan_card' => _SystemBubble(
        msg: msg,
        icon: Iconsax.card,
        color: AppColors.violet,
        wash: AppColors.violetWash,
        label: 'Plan options sent',
      ),
      'broadcast' => _SystemBubble(
        msg: msg,
        icon: Iconsax.send_2,
        color: AppColors.info,
        wash: AppColors.infoWash,
        label: 'Broadcast',
      ),
      _ => _TextBubble(
        msg: msg,
        onOpenImage: onOpenImage,
        isFirstInRun: isFirstInRun,
        isLastInRun: isLastInRun,
      ),
    };

    if (!showDaySeparator) return body;

    return Column(
      children: [
        _DaySeparator(raw: (msg['created_at'] ?? '').toString()),
        body,
      ],
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final String raw;

  const _DaySeparator({required this.raw});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final isToday =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        parsed.year == yesterday.year &&
        parsed.month == yesterday.month &&
        parsed.day == yesterday.day;

    final label = isToday
        ? 'Today'
        : isYesterday
        ? 'Yesterday'
        : Fmt.date.format(parsed);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final void Function(String, {bool isLocal}) onOpenImage;
  final bool isFirstInRun;
  final bool isLastInRun;

  const _TextBubble({
    required this.msg,
    required this.onOpenImage,
    this.isFirstInRun = true,
    this.isLastInRun = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isMine = msg['sender_type'] != 'user';
    final isAi = msg['source'] == 'ai_gemini';
    final sending = msg['_sending'] == true;
    final failed = msg['_failed'] == true;
    final text = (msg['message'] ?? '').toString();
    final isLocalImage = msg['_is_local_image'] == true;
    final imageUrl = isLocalImage
        ? msg['image_url']?.toString()
        : ApiConfig.resolveMediaUrl(msg['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Padding(
      // 2px inside a run, 8px between runs: the gap is what separates one
      // person's turn from the next.
      padding: EdgeInsets.only(bottom: isLastInRun ? 8 : 2),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.accentInk : AppColors.surface,
                    // The tail — the one squared corner — belongs to the last
                    // bubble of a run. Giving every bubble a tail made a run
                    // of five look like five separate turns.
                    // The tail corner is 10, not 4, and a mid-run corner
                    // is 12, not 6. Those were tight enough to read as square
                    // against an 18px opposite corner — enough of a tail to
                    // group a run, without a hard edge.
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        !isMine && !isFirstInRun ? 12 : 18,
                      ),
                      topRight: Radius.circular(
                        isMine && !isFirstInRun ? 12 : 18,
                      ),
                      bottomLeft: Radius.circular(
                        isMine || !isLastInRun ? 18 : 10,
                      ),
                      bottomRight: Radius.circular(
                        !isMine || !isLastInRun ? 18 : 10,
                      ),
                    ),
                    border: isMine ? null : Border.all(color: AppColors.border),
                  ),
                  padding: hasImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasImage) ...[
                        GestureDetector(
                          onTap: () =>
                              onOpenImage(imageUrl, isLocal: isLocalImage),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: isLocalImage
                                ? Image.file(
                                    File(imageUrl),
                                    width: 210,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    imageUrl,
                                    width: 210,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 210,
                                      height: 120,
                                      color: AppColors.surfaceAlt,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Iconsax.gallery_slash,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (text.isNotEmpty) const SizedBox(height: 6),
                      ],
                      if (text.isNotEmpty)
                        Padding(
                          padding: hasImage
                              ? const EdgeInsets.fromLTRB(9, 0, 9, 5)
                              : EdgeInsets.zero,
                          child: Text(
                            text,
                            style: t.bodyLarge?.copyWith(
                              fontSize: 14,
                              height: 1.35,
                              color: isMine
                                  ? AppColors.textOnInk
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isLastInRun || sending || failed) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAi) ...[
                        const AppPill(
                          label: 'AI',
                          color: AppColors.violet,
                          background: AppColors.violetWash,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (failed)
                        Text(
                          'Not sent',
                          style: t.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.danger,
                          ),
                        )
                      else if (sending)
                        Text(
                          'Sending…',
                          style: t.bodySmall?.copyWith(fontSize: 10),
                        )
                      else ...[
                        Text(
                          _time((msg['created_at'] ?? '').toString()),
                          style: t.bodySmall?.copyWith(fontSize: 10),
                        ),
                        // Delivery state, on our own messages only — the
                        // user's are read by definition once they are here.
                        // The backend already tracks is_read on admin rows;
                        // it was simply never shown, so an agent could not
                        // tell an unanswered message from an unseen one.
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg['is_read'] == true
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 13,
                            color: msg['is_read'] == true
                                ? AppColors.info
                                : AppColors.textTertiary,
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    // Called once per bubble, per frame, on threads that run to hundreds.
    return Fmt.time.format(parsed.toLocal());
  }
}

/// Renewal request, with the decision buttons on the message itself.
class _RenewalBubble extends StatelessWidget {
  final Map<String, dynamic> msg;

  /// RENEWAL_BUBBLE_DECISION_V1 — set as soon as the agent confirms, before
  /// the POST. The buttons are replaced by the outcome rather than disabled:
  /// a greyed-out pair of buttons says "wait", and there is nothing to wait
  /// for on this screen any more.
  final String? decision;

  final Future<void> Function(int, Map<String, dynamic>) onApprove;
  final Future<void> Function(int) onReject;
  final void Function(String, {bool isLocal}) onOpenImage;

  const _RenewalBubble({
    required this.msg,
    this.decision,
    required this.onApprove,
    required this.onReject,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final meta = msg['metadata'] as Map<String, dynamic>? ?? {};
    final reqId = msg['req_id'];
    // BUBBLE_DECIDED_LOCAL_V1 — a local, because a field cannot be promoted
    // to non-null and this is read four times in the branch below.
    final decided = decision;
    final planName = (meta['plan_name'] ?? 'Unknown plan').toString();
    final months = meta['duration_months'] ?? 0;
    final slots = meta['extra_device_slots'] ?? 0;
    final imageUrl = ApiConfig.resolveMediaUrl(msg['image_url']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 40),
      child: AppCard(
        radius: AppTheme.radiusMd,
        padding: const EdgeInsets.all(12),
        tone: SurfaceTone.wash,
        washColor: AppColors.warningWash,
        showShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Iconsax.receipt_item,
                  color: AppColors.warning,
                  background: AppColors.surface,
                  size: 15,
                  padding: 7,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Renewal request',
                    style: t.bodyLarge?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$planName · $months month${months == 1 ? '' : 's'}'
              '${slots > 0 ? ' · +$slots slot${slots == 1 ? '' : 's'}' : ''}',
              style: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => onOpenImage(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      color: AppColors.surfaceAlt,
                      alignment: Alignment.center,
                      child: const Icon(
                        Iconsax.gallery_slash,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (reqId is int) ...[
              const SizedBox(height: 12),
              // RENEWAL_BUBBLE_DECIDED_V1 — once decided the bubble shows the
              // outcome in place of the buttons, from the tap onward. A
              // failed POST clears the decision upstream and this row of
              // buttons comes back exactly as it was.
              if (decided != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppPill(
                    label: decided == 'approved'
                        ? 'အတည်ပြုပြီး'
                        : 'ငြင်းပယ်ပြီး',
                    icon: decided == 'approved'
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    color: decided == 'approved'
                        ? AppColors.success
                        : AppColors.danger,
                    background: decided == 'approved'
                        ? AppColors.successWash
                        : AppColors.dangerWash,
                  ),
                )
              else
              // TAP_TARGET_44_V1 — both were 38dp, inside a bubble, next to
              // each other, and one of them spends money. Raised to the 44
              // minimum; nothing else about them changes.
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => onReject(reqId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: () => onApprove(reqId, meta),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plan card and broadcast: system events, not conversation. Rendered as a
/// centred note rather than a bubble on either side, because neither is
/// something the agent typed.
class _SystemBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final IconData icon;
  final Color color;
  final Color wash;
  final String label;

  const _SystemBubble({
    required this.msg,
    required this.icon,
    required this.color,
    required this.wash,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final text = (msg['message'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: wash,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: t.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Composer ──────────────────────────────────────────────────────────────

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final File? selectedImage;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.selectedImage,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.controller.text.trim().isNotEmpty ||
        widget.selectedImage != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.selectedImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        widget.selectedImage!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photo attached',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClearImage,
                      icon: const Icon(Iconsax.close_circle, size: 18),
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: widget.onPickImage,
                    icon: const Icon(Iconsax.gallery, size: 21),
                    color: AppColors.textSecondary,
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      // Focusing is what raises the keyboard; without this an
                      // agent returning to a thread has to tap the narrow
                      // field itself rather than anywhere in the bar.
                      autofocus: false,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      // The server caps a reply at 2,000 characters and
                      // answers 422 past it. Enforced here so a long message
                      // is not typed out and then refused.
                      maxLength: 2000,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              // Only near the ceiling: a counter under every
                              // message is noise for the 20-character replies
                              // that make up most of a thread.
                              currentLength < 1800
                              ? null
                              : Text(
                                  '$currentLength / $maxLength',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: currentLength >= 2000
                                            ? AppColors.danger
                                            : AppColors.textTertiary,
                                      ),
                                ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Enabled only with something to send, and it does not
                  // dismiss the keyboard: agents usually send several lines in
                  // a row.
                  IconButton.filled(
                    onPressed: canSend
                        ? () {
                            HapticFeedback.lightImpact();
                            widget.onSend();
                            setState(() {});
                          }
                        : null,
                    icon: const Icon(Iconsax.send_1, size: 19),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accentInk,
                      foregroundColor: AppColors.textOnAccent,
                      disabledBackgroundColor: AppColors.surfaceAlt,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extend ────────────────────────────────────────────────────────────────

class _ExtendSheet extends StatefulWidget {
  final String username;
  final int planPrice;

  const _ExtendSheet({required this.username, required this.planPrice});

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  int _months = 1;
  int _days = 0;

  int get _cost =>
      ((_months * widget.planPrice) + (_days * widget.planPrice / 30)).ceil();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Extend subscription', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Charged to your balance immediately — ${widget.username} is not '
            'asked to pay.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Months',
                  value: _months,
                  max: 36,
                  onChanged: (v) => setState(() => _months = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Counter(
                  label: 'Days',
                  value: _days,
                  max: 29,
                  onChanged: (v) => setState(() => _days = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Cost', style: t.bodyMedium),
              const Spacer(),
              Text(
                // FMT_MONEY_SHEET_V1 — Fmt.money instead of a NumberFormat
                // built in this build method, which runs on every tap of the
                // month and day steppers.
                widget.planPrice == 0 ? '—' : Fmt.money.format(_cost),
                style: t.headlineMedium?.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (_months == 0 && _days == 0)
                ? null
                : () => Navigator.pop(context, {
                    'months': _months,
                    'days': _days,
                  }),
            child: const Text('Extend'),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  void _step(int delta) {
    final next = (value + delta).clamp(0, max);
    if (next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      radius: AppTheme.radiusMd,
      showShadow: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall),
          Row(
            children: [
              Text('$value', style: t.headlineMedium?.copyWith(fontSize: 22)),
              const Spacer(),
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: value > 0,
                onTap: () => _step(-1),
              ),
              const SizedBox(width: 6),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: value < max,
                onTap: () => _step(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.surfaceAlt : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String username;
  final bool isOnline;
  final double size;

  const _Avatar({
    required this.username,
    required this.isOnline,
    this.size = 40,
  });

  static const _avatars = [
    'assets/images/avatars/a1.png',
    'assets/images/avatars/a2.png',
  ];

  String get _asset {
    if (username.isEmpty) return _avatars.first;
    var hash = 0;
    for (final code in username.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _avatars[hash % _avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.asset(
              _asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;
  final bool isLocal;

  const _ImageViewer({required this.url, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.textOnInk,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: isLocal
              ? Image.file(File(url), fit: BoxFit.contain)
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const AppLoader(),
                  errorBuilder: (_, _, _) => const AppEmptyState(
                    icon: Iconsax.gallery_slash,
                    title: 'Could not load the image',
                  ),
                ),
        ),
      ),
    );
  }
}

/// Three dots while the user is composing.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // One controller, offset per dot, so the motion travels
                    // rather than pulsing in unison.
                    final t = (_c.value - i * 0.18) % 1.0;
                    final wave = t < 0.5
                        ? Curves.easeOut.transform(t * 2)
                        : 1 - Curves.easeIn.transform((t - 0.5) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.translate(
                        offset: Offset(0, -3 * wave),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.4 + 0.6 * wave,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
