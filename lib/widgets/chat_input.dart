import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// WhatsApp-style message composer with visible text and emoji picker.
class ChatMessageComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final bool isLoading;

  const ChatMessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Type a message...',
    this.isLoading = false,
  });

  @override
  State<ChatMessageComposer> createState() => _ChatMessageComposerState();
}

class _ChatMessageComposerState extends State<ChatMessageComposer> {
  static const _textColor = Color(0xFF1A1A1A);
  static const _hintColor = Color(0xFF6B7280);
  static const _accentColor = Color(0xFF043915);

  final _focusNode = FocusNode();
  bool _emojiVisible = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmojiPanel() {
    setState(() {
      _emojiVisible = !_emojiVisible;
      if (_emojiVisible) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final updated = text.replaceRange(start, end, emoji.emoji);
    widget.controller
      ..text = updated
      ..selection = TextSelection.collapsed(offset: start + emoji.emoji.length);
  }

  void _sendMessage() {
    if (widget.isLoading) return;
    widget.onSend();
    if (_emojiVisible) {
      setState(() => _emojiVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _emojiVisible ? 'Keyboard' : 'Emoji',
                    onPressed: _toggleEmojiPanel,
                    icon: Icon(
                      _emojiVisible
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: _hintColor,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _textColor,
                        height: 1.35,
                      ),
                      cursorColor: _accentColor,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: _hintColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onTap: () {
                        if (_emojiVisible) {
                          setState(() => _emojiVisible = false);
                        }
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: widget.isLoading ? null : _sendMessage,
                    icon: widget.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _accentColor,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: _accentColor,
                            size: 22,
                          ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),
            if (_emojiVisible)
              SizedBox(
                height: 280,
                child: EmojiPicker(
                  onEmojiSelected: _onEmojiSelected,
                  textEditingController: widget.controller,
                  config: Config(
                    height: 280,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: const EmojiViewConfig(
                      backgroundColor: Color(0xFFF0F2F5),
                      columns: 8,
                      emojiSizeMax: 28,
                      verticalSpacing: 6,
                      horizontalSpacing: 6,
                      gridPadding: EdgeInsets.symmetric(horizontal: 8),
                      recentsLimit: 32,
                      noRecents: Text(
                        'No recent emojis',
                        style: TextStyle(fontSize: 14, color: _hintColor),
                      ),
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      backgroundColor: Color(0xFFF0F2F5),
                      indicatorColor: _accentColor,
                      iconColor: _hintColor,
                      iconColorSelected: _accentColor,
                      backspaceColor: _hintColor,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Color(0xFFF0F2F5),
                      buttonColor: Colors.transparent,
                      buttonIconColor: _hintColor,
                    ),
                    searchViewConfig: const SearchViewConfig(
                      backgroundColor: Colors.white,
                      hintText: 'Search emoji',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
