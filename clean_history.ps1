# PowerShell script to replace API keys in git history
$openaiKey = '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'
$geminiKey = 'AIzaSyBQHIBtvLWP9spv2VF9lYrPpYqdS_gIB20'

$env:FILTER_BRANCH_SQUELCH_WARNING = '1'

git filter-branch --force --tree-filter "
if [ -f lib/services/ai_chat_service.dart ]; then
  sed -i 's|$openaiKey|YOUR_OPENAI_API_KEY_HERE|g' lib/services/ai_chat_service.dart
  sed -i 's|$geminiKey|YOUR_GEMINI_API_KEY_HERE|g' lib/services/ai_chat_service.dart
fi
" --prune-empty --tag-name-filter cat -- --all

