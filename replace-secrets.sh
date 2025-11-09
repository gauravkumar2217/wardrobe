#!/bin/sh
# Script to replace API keys in git history
if [ -f lib/services/ai_chat_service.dart ]; then
  sed -i.bak 's|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|YOUR_OPENAI_API_KEY_HERE|g' lib/services/ai_chat_service.dart
  sed -i.bak 's|AIzaSyBQHIBtvLWP9spv2VF9lYrPpYqdS_gIB20|YOUR_GEMINI_API_KEY_HERE|g' lib/services/ai_chat_service.dart
  rm -f lib/services/ai_chat_service.dart.bak 2>/dev/null
fi

