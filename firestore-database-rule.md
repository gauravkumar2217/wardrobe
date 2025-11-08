rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
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
      return data.keys().hasAll(['imageUrl', 'type', 'color', 'occasion', 'season', 'createdAt']) &&
             data.imageUrl is string &&
             data.type is string &&
             data.color is string &&
             data.occasion is string &&
             data.season is string &&
             data.createdAt is timestamp &&
             (data.lastWorn == null || data.lastWorn is timestamp);
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
          // Allow partial updates (e.g., just updating lastWorn or updatedAt)
          allow update: if isOwner(userId) &&
                         (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastWorn', 'updatedAt']) ||
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