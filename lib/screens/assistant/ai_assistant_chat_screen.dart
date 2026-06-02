import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/wardrobe_tokens.dart';

@immutable
class _AssistantMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime at;

  const _AssistantMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.at,
  });
}

class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _rnd = Random();

  bool _thinking = false;
  final List<_AssistantMessage> _messages = [
    _AssistantMessage(
      id: 'welcome',
      isUser: false,
      text:
          'Tell me what you’re wearing, the occasion, and the weather. I’ll suggest outfits from your wardrobe and a try-on plan.',
      at: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;
    _controller.clear();

    setState(() {
      _messages.add(
        _AssistantMessage(
          id: 'u_${DateTime.now().microsecondsSinceEpoch}',
          isUser: true,
          text: text,
          at: DateTime.now(),
        ),
      );
      _thinking = true;
    });
    _scrollToBottomSoon();

    // Placeholder “AI” response (no Gemini wired yet).
    await Future.delayed(const Duration(milliseconds: 650));
    final reply = _draftReply(text);

    if (!mounted) return;
    setState(() {
      _messages.add(
        _AssistantMessage(
          id: 'a_${DateTime.now().microsecondsSinceEpoch}',
          isUser: false,
          text: reply,
          at: DateTime.now(),
        ),
      );
      _thinking = false;
    });
    _scrollToBottomSoon();
  }

  String _draftReply(String userText) {
    final starters = [
      'Here’s a premium outfit plan:',
      'Style recommendation:',
      'Wardrobe AI suggestion:',
    ];
    final s = starters[_rnd.nextInt(starters.length)];

    // Keep response helpful but generic until we wire wardrobe items + Gemini.
    return [
      s,
      '',
      '- Occasion: (detected from your message) — confirm if it’s work/casual/date/party.',
      '- Base look: Dark top + tailored bottom + clean sneakers/loafers.',
      '- Accent: Add a gold accessory to match Wardrobe’s premium palette.',
      '',
      'Next: tell me your top 3 wardrobe items you want to wear (or upload more items), and I’ll generate 2–3 outfits + a try-on order.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (_thinking && i == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: _Bubble(
                      isUser: false,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Thinking…',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final m = _messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: _Bubble(
                    isUser: m.isUser,
                    child: Text(
                      m.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: m.isUser
                                ? scheme.onPrimary
                                : scheme.onSurface,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: WardrobeTokens.emeraldBg,
              border: Border(
                top: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask Wardrobe AI…',
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                      filled: true,
                      fillColor: WardrobeTokens.emeraldCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: WardrobeTokens.outlineGold),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: WardrobeTokens.outlineGold),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.95),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: FilledButton(
                    onPressed: _thinking ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final Widget child;

  const _Bubble({required this.isUser, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isUser ? scheme.primary : WardrobeTokens.emeraldCard;
    final borderColor = isUser
        ? scheme.primary.withValues(alpha: 0.65)
        : WardrobeTokens.outlineGold;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 18),
        ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

