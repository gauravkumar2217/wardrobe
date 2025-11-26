Complete Wardrobe App Implementation Plan
Overview
Complete all missing screens and features according to app-plan.md, improve existing screens to match the design specification, and ensure proper navigation throughout the app.

Phase 1: Home Screen Improvements
1.1 Make Home Screen Fullscreen (Reels-style)
File: lib/screens/home/home_screen.dart
Remove AppBar, make scaffold fullscreen
Add transparent back button at top-left
Add wardrobe filter button at top (if wardrobe selected, show filter indicator)
Add floating action button for "Add Cloth" (bottom-right)
Implement proper wardrobe filter: when wardrobe is selected, show only that wardrobe's clothes
Add pull-to-refresh functionality
1.2 Complete Cloth Card Widget
File: lib/widgets/cloth_card.dart
Add back button at top-left (transparent, only if not in PageView)
Complete bottom information panel with:
Season, Placement, Color tags (already present)
Cloth type, Category, Occasions (already present)
Wardrobe name (NEW - fetch from wardrobe service)
Added date (NEW - format createdAt)
Worn history summary (NEW - "Worn X times, last worn Y days ago")
Improve styling: better gradient, better spacing
Add loading state for image
1.3 Implement Like/Comment/Share Functionality
File: lib/screens/home/home_screen.dart
Wire up onLike to call ClothService.likeCloth() / unlikeCloth()
Check like status from clothes/{clothId}/likes/{userId} subcollection
Wire up onComment to show comment dialog or navigate to comment screen
Wire up onShare to show share dialog (only for owner's clothes)
Update cloth provider to refresh likes/comments count after actions
1.4 Add Navigation
Add navigation to:
Profile screen (from profile icon)
Notifications screen (from notification icon)
Wardrobe list screen (from filter button or drawer)
Add cloth screen (from FAB)
Phase 2: Missing Screens - Friends Features
2.1 Friends List Screen
File: lib/screens/friends/friends_list_screen.dart (NEW)
Display list of all friends
Show friend avatar, name, last active
Tap to view friend's profile (if public) or start chat
Add "Add Friend" button at top
Use FriendService.getFriends() and FriendProvider
2.2 Friend Requests Screen
File: lib/screens/friends/friend_requests_screen.dart (NEW)
Two tabs: "Received" and "Sent"
Received requests: Show sender info, Accept/Reject buttons
Sent requests: Show recipient info, Cancel button
Use FriendService.getFriendRequests() and FriendProvider
Implement accept/reject/cancel actions
2.3 Search Users Screen
File: lib/screens/friends/search_users_screen.dart (NEW)
Search bar at top
Search by name, email, or phone
Display search results with avatar, name, friend status
"Add Friend" button for non-friends
"Message" button for friends
Use FriendService.searchUsers() and FriendProvider
Phase 3: Profile & Settings Screens
3.1 Profile Screen
File: lib/screens/profile/profile_screen.dart (NEW)
Display user info: avatar, name, email, phone
Show wardrobe stats: total wardrobes, total clothes, most worn item
Action buttons: Edit Profile, Settings, Logout
Navigation to wardrobe list, friends list
3.2 Settings Screen
File: lib/screens/profile/settings_screen.dart (NEW)
Sections:
Account: Edit profile, Change password, Verify phone/email
Notifications (granular controls):
Friend request notifications (toggle)
Friend accept notifications (toggle)
DM message notifications (toggle)
Cloth like notifications (toggle)
Cloth comment notifications (toggle)
Suggestion notifications (toggle)
Quiet hours (time picker for start/end)
Privacy: Profile visibility, Wardrobe visibility, Allow DM from non-friends
About: Privacy Policy, Terms & Conditions, About, Version
Danger Zone: Logout, Delete Account (with OTP confirmation)
Use UserService.updateUserProfile() and AuthProvider
Save settings to users/{userId}.settings in Firestore
Phase 4: Notifications Screen
4.1 Notifications Screen
File: lib/screens/notifications/notifications_screen.dart (NEW)
Display all notifications from users/{userId}/notifications
Group by type: Friend requests, Likes, Comments, Messages, Suggestions
Show unread badge count
Mark as read on tap
Deep link to relevant screen (cloth detail, chat, friend request)
Pull to refresh
Use NotificationService and NotificationProvider
Phase 5: Cloth Detail Screen (for DM Shared Clothes)
5.1 Cloth Detail Screen
File: lib/screens/cloth/cloth_detail_screen.dart (NEW)
Fullscreen cloth card (reuse ClothCard widget)
Swipe up/down navigation between clothes
For shared clothes (from DM):
Show Like and Comment only
Hide Share, Mark Worn, Edit buttons
For own clothes:
Show all actions including Edit
Navigate from chat detail screen when cloth is tapped
Phase 6: Navigation Structure
6.1 Main Navigation
File: lib/main.dart or new lib/screens/main_navigation.dart
Add bottom navigation bar with tabs:
Home (cloth feed)
Wardrobes (wardrobe list)
Friends (friends list)
Chats (chat list)
Profile (profile screen)
Or use drawer navigation
Update HomeScreen to be part of navigation structure
6.2 Update All Screen Navigation
Connect all screens with proper navigation
Add back button handling
Update wardrobe list screen to navigate to home with filter
Update chat detail to navigate to cloth detail for shared clothes
Phase 7: Like/Comment Implementation
7.1 Like Functionality
File: lib/providers/cloth_provider.dart
Add toggleLike() method that calls ClothService.likeCloth() or unlikeCloth()
Track like status in provider state
Refresh cloth list after like/unlike
7.2 Comment Functionality
File: lib/screens/cloth/comment_screen.dart (NEW) or use dialog
Display all comments from clothes/{clothId}/comments
Add comment input at bottom
Submit comment using ClothService.addComment()
Real-time updates using Firestore stream
7.3 Share Functionality
File: lib/screens/home/home_screen.dart
Show share dialog with options:
Share to DM (select friend/chat)
Copy link (if implemented)
For DM share: use ChatService.sendMessage() with clothId field
Phase 8: Rules Verification & Updates
8.1 Storage Rules Check
File: storage.rules
Verify paths match service usage:
✅ users/{userId}/profile/{imageName} - matches StorageService
✅ users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}/{imageName} - matches StorageService
✅ users/{userId}/chats/{chatId}/messages/{messageId}/images/{imageName} - matches StorageService
Status: Rules are correct, no changes needed
8.2 Firestore Rules Check
File: firestore.rules
Verify all collections have proper rules:
✅ config/tagLists - public read, admin write
✅ users/{userId} - owner read/write, limited friend read
✅ users/{userId}/wardrobes/{wardrobeId} - owner read/write
✅ users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId} - visibility-based read
✅ users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}/likes/{likeId} - authenticated users can like
✅ users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}/comments/{commentId} - authenticated users can comment
✅ friendRequests/{requestId} - participants can read/write
✅ users/{userId}/chats/{chatId} - participants can read/write
✅ users/{userId}/notifications/{notificationId} - owner read/write
Status: Rules appear complete, verify during testing
Phase 9: Additional Improvements
9.1 Cloth Provider Enhancements
File: lib/providers/cloth_provider.dart
Add method to check if cloth is liked by current user
Add method to get wardrobe name for cloth
Add method to get wear history summary
Add real-time listeners for likes/comments updates
9.2 Wardrobe Provider Enhancements
File: lib/providers/wardrobe_provider.dart
Add method to get wardrobe by ID (for cloth card display)
Cache wardrobe data for quick access
9.3 Error Handling & Loading States
Add proper error messages throughout
Add loading indicators where needed
Handle empty states (no clothes, no friends, etc.)
Implementation Order
Home Screen Improvements (Phase 1) - Core user experience
Navigation Structure (Phase 6) - Connect all screens
Like/Comment Implementation (Phase 7) - Core interactions
Friends Features (Phase 2) - Social features
Profile & Settings (Phase 3) - User management
Notifications Screen (Phase 4) - Notification center
Cloth Detail Screen (Phase 5) - DM shared clothes
Rules Verification (Phase 8) - Security check
Additional Improvements (Phase 9) - Polish
Files to Create
lib/screens/friends/friends_list_screen.dart
lib/screens/friends/friend_requests_screen.dart
lib/screens/friends/search_users_screen.dart
lib/screens/profile/profile_screen.dart
lib/screens/profile/settings_screen.dart
lib/screens/notifications/notifications_screen.dart
lib/screens/cloth/cloth_detail_screen.dart
lib/screens/cloth/comment_screen.dart (or use dialog)
lib/screens/main_navigation.dart (optional, if using bottom nav)
Files to Modify
lib/screens/home/home_screen.dart - Fullscreen, navigation, like/comment/share
lib/widgets/cloth_card.dart - Complete info panel, back button
lib/providers/cloth_provider.dart - Like status, wardrobe name, wear history
lib/providers/wardrobe_provider.dart - Get wardrobe by ID
lib/main.dart - Add navigation structure (if needed)
Testing Checklist
[ ] Home screen is fullscreen with proper navigation
[ ] Cloth card shows all required information
[ ] Like/Comment/Share functionality works
[ ] Wardrobe filter works correctly
[ ] Friends list, requests, and search work
[ ] Profile and settings screens work
[ ] Notifications screen displays and deep links work
[ ] Cloth detail screen works for DM shared clothes
[ ] All navigation flows work correctly
[ ] Storage and Firestore rules are properly enforced