import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ultra_sync/core/di/injection.dart';
import 'package:ultra_sync/core/ports/token_storage.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';
import 'package:ultra_sync/core/utils/jwt_decoder.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_event.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_state.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  const ChatPage({super.key, required this.roomId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUser();
    
    // Load chat history & Subscribe to live WebSockets channel
    context.read<ChatBloc>().add(ChatHistoryRequested(widget.roomId));
    context.read<ChatBloc>().add(ChatStreamSubscribed(widget.roomId));
  }

  Future<void> _loadUser() async {
    final tokenStorage = getIt<TokenStorage>();
    final token = await tokenStorage.getAccessToken();
    if (token != null && mounted) {
      setState(() {
        _currentUserId = JwtDecoder.getUserId(token);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChatBloc>().add(ChatMessageSent(widget.roomId, text));
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBgColor = isDark ? AppColorsDark.onBackground : AppColors.onBackground;
    final surfaceColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final dividerColor = isDark ? AppColorsDark.divider : AppColors.divider;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Chat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Connected to Driver',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state is ChatHistoryLoaded) {
                    _scrollToBottom();
                    if (state.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage!),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (state is ChatError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(state.message, style: const TextStyle(color: AppColors.error)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<ChatBloc>().add(ChatHistoryRequested(widget.roomId));
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is ChatHistoryLoaded) {
                    final messages = state.messages;
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Send a message to start conversation',
                              style: TextStyle(
                                color: isDark ? AppColorsDark.onSurface : AppColors.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == _currentUserId || (_currentUserId == null && msg.senderRole == 'user');

                        // Show date label on new day
                        final showDate = index == 0 ||
                            msg.createdAt.difference(messages[index - 1].createdAt).inDays > 0;

                        return Column(
                          children: [
                            if (showDate) _DateHeader(date: msg.createdAt),
                            _ChatBubble(msg: msg, isMe: isMe),
                          ],
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: onBgColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColorsDark.onSurface : AppColors.onSurface,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.primary,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
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

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColorsDark.onSurface : AppColors.onSurface;
    final containerColor = isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  const _ChatBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe
        ? null
        : (isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant);
    final textStyle = TextStyle(
      color: isMe ? Colors.white : (isDark ? AppColorsDark.onBackground : AppColors.onBackground),
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppGradients.primary : null,
                    color: isMe ? null : bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: isMe ? AppShadows.primary : null,
                  ),
                  child: Text(
                    msg.content,
                    style: textStyle,
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 36,
              right: isMe ? 8 : 0,
              top: 4,
            ),
            child: Text(
              DateFormat('hh:mm a').format(msg.createdAt),
              style: TextStyle(
                color: isDark ? AppColorsDark.onSurface.withValues(alpha: 0.6) : AppColors.onSurface.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
