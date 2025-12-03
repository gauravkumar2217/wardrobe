import 'package:flutter/foundation.dart';
import '../models/friend_request.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';

/// Friend provider for managing friends and friend requests
class FriendProvider with ChangeNotifier {
  List<String> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get friends => _friends;
  List<FriendRequest> get incomingRequests => _incomingRequests;
  List<FriendRequest> get outgoingRequests => _outgoingRequests;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load friends list
  Future<void> loadFriends(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _friends = await FriendService.getFriends(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load friends: ${e.toString()}';
      debugPrint('Error loading friends: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch friends for real-time updates
  void watchFriends(String userId) {
    FriendService.watchFriends(userId).listen((friends) {
      _friends = friends;
      _errorMessage = null;
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch friends: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Load friend requests
  Future<void> loadFriendRequests(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _incomingRequests = await FriendService.getFriendRequests(
        userId: userId,
        type: 'incoming',
      );
      _outgoingRequests = await FriendService.getFriendRequests(
        userId: userId,
        type: 'outgoing',
      );
      _errorMessage = null;
      debugPrint('Loaded ${_incomingRequests.length} incoming and ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      _errorMessage = 'Failed to load friend requests: ${e.toString()}';
      debugPrint('Error loading friend requests: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch friend requests for real-time updates
  void watchFriendRequests(String userId) {
    FriendService.watchFriendRequests(userId: userId, type: 'incoming')
        .listen((requests) {
      _incomingRequests = requests;
      notifyListeners();
    });

    FriendService.watchFriendRequests(userId: userId, type: 'outgoing')
        .listen((requests) {
      _outgoingRequests = requests;
      notifyListeners();
    });
  }

  /// Send friend request
  Future<bool> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FriendService.sendFriendRequest(
        fromUserId: fromUserId,
        toUserId: toUserId,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send friend request: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Find the request in local list to get fromUserId for immediate UI update
      // If not found locally, we'll still proceed - the service will fetch it
      String? fromUserId;
      int? requestIndex;
      
      // Safely find the request index
      if (_incomingRequests.isNotEmpty) {
        requestIndex = _incomingRequests.indexWhere((r) => r.id == requestId);
        if (requestIndex != -1 && requestIndex < _incomingRequests.length) {
          fromUserId = _incomingRequests[requestIndex].fromUserId;
        } else {
          requestIndex = null; // Invalid index, don't try to remove
        }
      }
      
      await FriendService.acceptFriendRequest(requestId);
      
      // Remove from local list if it was there and index is valid
      if (requestIndex != null && 
          requestIndex != -1 && 
          requestIndex < _incomingRequests.length &&
          _incomingRequests.isNotEmpty) {
        try {
          _incomingRequests.removeAt(requestIndex);
        } catch (e) {
          // If removal fails, try removing by ID instead
          _incomingRequests.removeWhere((r) => r.id == requestId);
        }
      } else {
        // Fallback: remove by ID if index lookup failed
        _incomingRequests.removeWhere((r) => r.id == requestId);
      }
      
      // Add the friend to the friends list immediately if we have the fromUserId
      if (fromUserId != null && fromUserId.isNotEmpty && !_friends.contains(fromUserId)) {
        _friends.add(fromUserId);
      }
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept friend request: ${e.toString()}';
      debugPrint('Error accepting friend request: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FriendService.rejectFriendRequest(requestId);
      _incomingRequests.removeWhere((r) => r.id == requestId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject friend request: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FriendService.cancelFriendRequest(requestId);
      _outgoingRequests.removeWhere((r) => r.id == requestId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel friend request: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove friend
  Future<bool> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FriendService.removeFriend(
        userId: userId,
        friendId: friendId,
      );
      _friends.remove(friendId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove friend: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search users
  Future<void> searchUsers(String query) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await UserService.searchUsers(query);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to search users: ${e.toString()}';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if users are friends
  Future<bool> checkFriendship(String userId1, String userId2) async {
    try {
      return await FriendService.checkFriendship(userId1, userId2);
    } catch (e) {
      debugPrint('Failed to check friendship: $e');
      return false;
    }
  }

  /// Check friend request status between two users
  /// Returns: Map with 'status' ('none', 'outgoing', 'incoming', or 'friends') and 'requestId'
  Future<Map<String, dynamic>> checkFriendRequestStatus({
    required String userId1,
    required String userId2,
  }) async {
    try {
      return await FriendService.checkFriendRequestStatus(
        userId1: userId1,
        userId2: userId2,
      );
    } catch (e) {
      debugPrint('Failed to check friend request status: $e');
      return {'status': 'none', 'requestId': null};
    }
  }

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

