rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // FCM Tokens Collection: users/{userId}/fcmTokens/{tokenId}
    // Store FCM tokens for push notifications - only active users receive notifications
    match /users/{userId}/fcmTokens/{tokenId} {
      // Allow read if user owns the token
      allow read: if isOwner(userId);
      
      // Allow create if user owns the token and data is valid
      allow create: if isOwner(userId) &&
                     request.resource.data.keys().hasAll(['token', 'userId', 'isActive', 'lastActive', 'createdAt', 'updatedAt']) &&
                     request.resource.data.token is string &&
                     request.resource.data.token.size() > 0 &&
                     request.resource.data.userId is string &&
                     request.resource.data.userId == userId &&
                     request.resource.data.isActive is bool &&
                     request.resource.data.lastActive is timestamp &&
                     request.resource.data.createdAt is timestamp &&
                     request.resource.data.updatedAt is timestamp;
      
      // Allow update if user owns the token (for updating isActive, lastActive, etc.)
      allow update: if isOwner(userId) &&
                     (!('token' in request.resource.data) || (request.resource.data.token is string && request.resource.data.token.size() > 0)) &&
                     (!('userId' in request.resource.data) || (request.resource.data.userId is string && request.resource.data.userId == userId)) &&
                     (!('isActive' in request.resource.data) || request.resource.data.isActive is bool) &&
                     (!('lastActive' in request.resource.data) || request.resource.data.lastActive is timestamp) &&
                     (!('updatedAt' in request.resource.data) || request.resource.data.updatedAt is timestamp);
      
      // Allow delete if user owns the token (for cleanup on app uninstall)
      allow delete: if isOwner(userId);
    }
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Helper function to validate wardrobe data
    function isValidWardrobe(data) {
      return data.keys().hasAll(['title', 'location', 'season', 'createdAt', 'updatedAt', 'clothCount']) &&
             data.title is string &&
             data.title.size() > 0 &&
             data.location is string &&
             data.season is string &&
             data.createdAt is timestamp &&
             data.updatedAt is timestamp &&
             data.clothCount is int &&
             data.clothCount >= 0;
    }
    
    // Helper function to validate cloth data
    function isValidCloth(data) {
      // Validate required fields - support both new format (occasions list) and old format (occasion string)
      return data.keys().hasAll(['imageUrl', 'type', 'color', 'season', 'createdAt']) &&
             data.imageUrl is string &&
             data.type is string &&
             data.color is string &&
             data.season is string &&
             data.createdAt is timestamp &&
             (data.lastWorn == null || data.lastWorn is timestamp) &&
             // Require 'occasions' (new format) - must be a list with at least one item
             // Also allow 'occasion' field for backward compatibility (optional)
             ('occasions' in data) &&
             data.occasions is list &&
             data.occasions.size() > 0 &&
             // Optional: allow 'occasion' field for backward compatibility (but not required)
             (!('occasion' in data) || data.occasion is string);
    }
    
    // Helper function to validate suggestion data
    function isValidSuggestion(data) {
      return data.keys().hasAll(['wardrobeId', 'clothIds', 'createdAt', 'viewed']) &&
             data.wardrobeId is string &&
             data.clothIds is list &&
             data.createdAt is timestamp &&
             data.viewed is bool &&
             (data.reason == null || data.reason is string);
    }
    
    // Helper function to validate chat message data
    function isValidChatMessage(data) {
      return data.keys().hasAll(['role', 'content', 'timestamp']) &&
             data.role is string &&
             (data.role == 'user' || data.role == 'assistant') &&
             data.content is string &&
             data.content.size() > 0 &&
             data.timestamp is timestamp;
    }
    
    // User Profile Document: users/{userId}
    match /users/{userId} {
      // Allow read if user owns the profile
      allow read: if isOwner(userId);
      
      // Allow create if user owns the profile and data is valid
      allow create: if isOwner(userId) &&
                     (!('name' in request.resource.data) || request.resource.data.name is string) &&
                     (!('gender' in request.resource.data) || request.resource.data.gender is string) &&
                     (!('birthday' in request.resource.data) || request.resource.data.birthday is string) &&
                     (!('plan' in request.resource.data) || request.resource.data.plan is map);
      
      // Allow update if user owns the profile (merge allowed)
      allow update: if isOwner(userId) &&
                     (!('name' in request.resource.data) || request.resource.data.name is string) &&
                     (!('gender' in request.resource.data) || request.resource.data.gender is string) &&
                     (!('birthday' in request.resource.data) || request.resource.data.birthday is string) &&
                     (!('plan' in request.resource.data) || request.resource.data.plan is map);
      
      // Allow delete if user owns the profile
      allow delete: if isOwner(userId);
      
      // Wardrobes Subcollection: users/{userId}/wardrobes/{wardrobeId}
      match /wardrobes/{wardrobeId} {
        // Allow read if user owns the wardrobe
        allow read: if isOwner(userId);
        
        // Allow create if user owns the wardrobe and data is valid
        allow create: if isOwner(userId) && isValidWardrobe(request.resource.data);
        
        // Allow update if user owns the wardrobe and data is valid
        allow update: if isOwner(userId) && 
                       isValidWardrobe(request.resource.data) &&
                       request.resource.data.updatedAt == request.time;
        
        // Allow delete if user owns the wardrobe
        allow delete: if isOwner(userId);
        
        // Clothes Subcollection: users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}
        match /clothes/{clothId} {
          // Allow read if user owns the cloth
          allow read: if isOwner(userId);
          
          // Allow create if user owns the cloth and data is valid
          allow create: if isOwner(userId) && isValidCloth(request.resource.data);
          
          // Allow update if user owns the cloth
          // Allow partial updates (e.g., just updating lastWorn, updatedAt, occasions, or other fields)
          allow update: if isOwner(userId) &&
                         (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastWorn', 'updatedAt']) ||
                          // Allow updates to occasions, type, color, season individually
                          (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['occasions', 'occasion']) &&
                           request.resource.data.occasions is list &&
                           request.resource.data.occasions.size() > 0) ||
                          (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['type']) &&
                           request.resource.data.type is string) ||
                          (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['color']) &&
                           request.resource.data.color is string) ||
                          (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['season']) &&
                           request.resource.data.season is string) ||
                          // Full validation for complete updates
                          isValidCloth(request.resource.data));
          
          // Allow delete if user owns the cloth
          allow delete: if isOwner(userId);
        }
      }
      
      // Suggestions Collection: users/{userId}/suggestions/{suggestionId}
      match /suggestions/{suggestionId} {
        // Allow read if user owns the suggestion
        allow read: if isOwner(userId);
        
        // Allow create if user owns the suggestion and data is valid
        allow create: if isOwner(userId) && isValidSuggestion(request.resource.data);
        
        // Allow update if user owns the suggestion (e.g., mark as viewed)
        allow update: if isOwner(userId) &&
                       (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['viewed']) ||
                        isValidSuggestion(request.resource.data));
        
        // Allow delete if user owns the suggestion
        allow delete: if isOwner(userId);
      }
      
      // Chats Collection: users/{userId}/chats/{chatId}
      match /chats/{chatId} {
        // Allow read if user owns the chat
        allow read: if isOwner(userId);
        
        // Allow create if user owns the chat
        allow create: if isOwner(userId) &&
                       (!('createdAt' in request.resource.data) || request.resource.data.createdAt is timestamp) &&
                       (!('updatedAt' in request.resource.data) || request.resource.data.updatedAt is timestamp);
        
        // Allow update if user owns the chat (for metadata updates)
        allow update: if isOwner(userId) &&
                       (!('createdAt' in request.resource.data) || request.resource.data.createdAt is timestamp) &&
                       (!('updatedAt' in request.resource.data) || request.resource.data.updatedAt is timestamp);
        
        // Allow delete if user owns the chat
        allow delete: if isOwner(userId);
        
        // Chat Messages Subcollection: users/{userId}/chats/{chatId}/messages/{messageId}
        match /messages/{messageId} {
          // Allow read if user owns the message
          allow read: if isOwner(userId);
          
          // Allow create if user owns the message and data is valid
          allow create: if isOwner(userId) && isValidChatMessage(request.resource.data);
          
          // Allow update if user owns the message (rarely used, but allowed)
          allow update: if isOwner(userId) && isValidChatMessage(request.resource.data);
          
          // Allow delete if user owns the message
          allow delete: if isOwner(userId);
        }
      }
    }
  }
}