import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/messaging/private_messaging_service.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/private_conversation.dart';
import '../../models/service_transaction.dart';
import '../../providers/private_messaging_provider.dart';
import '../../providers/service_transaction_provider.dart';

class PrivateTransactionChatScreen extends StatefulWidget {
  final String transactionId;
  final String actorId;

  const PrivateTransactionChatScreen({
    required this.transactionId,
    required this.actorId,
    super.key,
  });

  @override
  State<PrivateTransactionChatScreen> createState() =>
      _PrivateTransactionChatScreenState();
}

class _PrivateTransactionChatScreenState
    extends State<PrivateTransactionChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _opening = true;
  Object? _openError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openConversation();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation() async {
    try {
      final conversation =
          await context.read<PrivateMessagingProvider>().ensureConversation(
                transactionId: widget.transactionId,
                actorId: widget.actorId,
              );
      if (!mounted) return;
      await context.read<PrivateMessagingProvider>().markConversationRead(
            transactionId: widget.transactionId,
            readerId: widget.actorId,
          );
      if (!mounted) return;
      setState(() {
        _opening = false;
        _openError = null;
      });
      if (!conversation.storage.storageChoiceConfirmed) {
        await _showInitialStorageChoice();
      }
      _scrollToBottom();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _openError = error;
      });
    }
  }

  Future<void> _showInitialStorageChoice() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Chat Storage'),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HDC lets transaction participants choose where chat history '
                'will ultimately be retained.',
                style: TextStyle(height: 1.45),
              ),
              SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cloud_outlined),
                title: Text('HDC Storage'),
                subtitle: Text(
                  'Available in this beta. Storage is limited and the quota '
                  'may change in future versions.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                leading: Icon(Icons.folder_outlined),
                title: Text('My Storage'),
                subtitle: Text(
                  'The provider-neutral adapter is prepared, but an authorized '
                  'Drive, OneDrive, or user-folder connector is not connected '
                  'in this developer build yet.',
                ),
              ),
              SizedBox(height: 12),
              const Text(
                'For this build, continue with HDC Storage. The frontend never '
                'receives backend storage credentials or another user\'s '
                'authorization token.',
                style: TextStyle(
                  fontSize: 12,
                  color: HDCColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HDCColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HDCColors.warning.withValues(alpha: 0.22),
                  ),
                ),
                child: const Text(
                  'Beta Chat Storage Notice: During the HDC Beta, chat history '
                  'is stored locally on this device. If HDC is uninstalled, its '
                  'app data is cleared, or this device becomes unavailable, your '
                  'chat history may not be recoverable. Cloud backup and '
                  'user-owned storage restore options are planned for future '
                  'versions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: HDCColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await context
                  .read<PrivateMessagingProvider>()
                  .updateStorageMode(
                    transactionId: widget.transactionId,
                    actorId: widget.actorId,
                    mode: ConversationStorageMode.hdcManaged,
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Use HDC Storage'),
          ),
        ],
      ),
    );
  }

  Future<void> _send({
    bool acknowledgeLanguageWarning = false,
  }) async {
    final text = _messageController.text;

    if (text.trim().isEmpty) return;

    try {
      await context.read<PrivateMessagingProvider>().sendMessage(
            transactionId: widget.transactionId,
            senderId: widget.actorId,
            text: text,
            acknowledgeLanguageWarning: acknowledgeLanguageWarning,
          );

      _messageController.clear();
      _scrollToBottom();
    } on PrivateMessageWarningRequired catch (warning) {
      if (!mounted) return;

      final sendAnyway = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Language Warning'),
          content: Text(
            '${warning.message}\n\n'
            'Private chat allows you to continue, but HDC encourages '
            'respectful communication between transaction participants.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Edit Message'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send Anyway'),
            ),
          ],
        ),
      );

      if (sendAnyway == true && mounted) {
        await _send(acknowledgeLanguageWarning: true);
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message could not be sent: $error'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transaction = context
        .watch<ServiceTransactionProvider>()
        .byId(widget.transactionId);
    final messaging = context.watch<PrivateMessagingProvider>();
    final conversation = messaging.forTransaction(widget.transactionId);

    if (transaction == null) {
      return const Scaffold(
        body: Center(
          child: Text('Service transaction was not found.'),
        ),
      );
    }

    if (_opening) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_openError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Private chat could not be opened.\n\n$_openError',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (conversation == null) {
      return const Scaffold(
        body: Center(
          child: Text('Conversation is unavailable.'),
        ),
      );
    }

    final otherName = widget.actorId == transaction.customerId
        ? transaction.technicianName
        : transaction.customerName;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherName),
            Text(
              transaction.id,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat storage',
            onPressed: () => _showStorageSheet(
              context,
              conversation,
            ),
            icon: const Icon(Icons.cloud_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TransactionContextBanner(transaction: transaction),
            _StorageUsageBanner(conversation: conversation),
            Expanded(
              child: conversation.messages.isEmpty
                  ? const _EmptyConversation()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      itemCount: conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = conversation.messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == widget.actorId,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _messageController,
              isSending: messaging.isSaving,
              enabled: transaction.allowsPrivateMessaging,
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStorageSheet(
    BuildContext context,
    PrivateConversation conversation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final usedKb = conversation.approximateStorageBytes / 1024;
        final quotaMb = conversation.storage.quotaBytes / (1024 * 1024);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chat Storage',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${conversation.storage.mode.label} • '
                '${usedKb.toStringAsFixed(1)} KB used of '
                '${quotaMb.toStringAsFixed(0)} MB beta quota',
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _StorageOption(
                title: 'HDC Storage',
                subtitle:
                    'Active in this beta. Capacity is limited and may change '
                    'in future versions.',
                selected: conversation.storage.mode ==
                    ConversationStorageMode.hdcManaged,
                enabled: true,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await context
                      .read<PrivateMessagingProvider>()
                      .updateStorageMode(
                        transactionId: widget.transactionId,
                        actorId: widget.actorId,
                        mode: ConversationStorageMode.hdcManaged,
                      );
                },
              ),
              const SizedBox(height: 10),
              _StorageOption(
                title: 'My Storage',
                subtitle:
                    'Provider-neutral adapter is ready, but an authorized '
                    'Drive/OneDrive/local-folder connector is not connected '
                    'in this build yet.',
                selected: conversation.storage.mode ==
                    ConversationStorageMode.userOwned,
                enabled: false,
                onTap: null,
              ),
              const SizedBox(height: 18),
              const Text(
                'Beta Chat Storage Notice: Chat history is stored locally in '
                'this beta. If HDC is uninstalled, app data is cleared, or the '
                'device becomes unavailable, the history may not be recoverable. '
                'True uninstall-safe restore requires the protected HDC backend '
                'or an authorized user-owned storage provider. The storage '
                'contracts are already separated for that migration.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionContextBanner extends StatelessWidget {
  final ServiceTransaction transaction;

  const _TransactionContextBanner({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: HDCColors.secondary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.handshake_outlined,
            color: HDCColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${transaction.requestTitle} • '
              '${transaction.status.label} • '
              'PHP ${transaction.acceptedTerms.totalEstimate.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageUsageBanner extends StatelessWidget {
  final PrivateConversation conversation;

  const _StorageUsageBanner({
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        conversation.storageUsageRatio.clamp(0.0, 1.0).toDouble();
    final usedKb = conversation.approximateStorageBytes / 1024;
    final quotaMb = conversation.storage.quotaBytes / (1024 * 1024);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                conversation.storage.mode.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: HDCColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${usedKb.toStringAsFixed(1)} KB / '
                '${quotaMb.toStringAsFixed(0)} MB',
                style: const TextStyle(
                  fontSize: 11,
                  color: HDCColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: ratio),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 54,
              color: HDCColors.textSecondary,
            ),
            SizedBox(height: 14),
            Text(
              'Start the transaction conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Use this private chat to discuss the technology issue, '
              'service progress, and transaction details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HDCColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final PrivateMessage message;
  final bool isMine;

  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        isMine ? HDCColors.secondary : HDCColors.surface;

    final foreground = isMine ? Colors.white : HDCColors.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: isMine ? null : Border.all(color: HDCColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: foreground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_time(message.createdAt)} • ${message.status.label}',
              style: TextStyle(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.72)
                    : HDCColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isSending,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: HDCColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Message transaction participant...'
                      : 'Messaging is read-only for this transaction',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (enabled && !isSending) {
                    onSend();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: !enabled || isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _StorageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? HDCColors.secondary : HDCColors.border,
        ),
      ),
      leading: Icon(
        selected
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: enabled
          ? null
          : const Chip(
              label: Text('Connector required'),
            ),
    );
  }
}
