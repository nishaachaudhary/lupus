import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lupus_care/data/model/view_user_model.dart';
import 'dart:async';

class ViewMembersController extends ChangeNotifier {
  final List<ViewMember> _members = [];
  List<ViewMember> filteredMembers = [];
  final TextEditingController searchController = TextEditingController();

  bool isLoading = false;
  String? error;
  String? groupId;
  StreamSubscription<DocumentSnapshot>? _groupSubscription;

  List<ViewMember> get members => _members;

  void init({String? groupId}) {
    print("🚀 ViewMembersController.init() called");
    print("📋 Received groupId: '$groupId'");

    this.groupId = groupId;
    searchController.addListener(_filterMembers);

    if (groupId != null && groupId.isNotEmpty) {
      print("🔥 Starting member loading process...");
      loadMembers();
      _setupRealtimeUpdates();
    } else {
      error = "No group ID provided";
      notifyListeners();
    }
  }

  void _setupRealtimeUpdates() {
    if (groupId == null) return;

    _groupSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(groupId!)
        .snapshots()
        .listen(
          (snapshot) {
        if (snapshot.exists) {
          print("🔄 Group data updated, refreshing members...");
          loadMembers();
        }
      },
      onError: (error) {
        print("❌ Error in group subscription: $error");
      },
    );
  }

  Future<void> loadMembers() async {
    print("🔄 ============ LOADING MEMBERS ============");
    print("🔥 Target group ID: $groupId");

    if (groupId == null) {
      error = "No group ID provided";
      notifyListeners();
      return;
    }

    try {
      isLoading = true;
      error = null;
      notifyListeners();

      print("🔥 Querying Firestore for group: $groupId");

      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId!)
          .get();

      print("📋 Firestore query complete");
      print("📋 Document exists: ${groupDoc.exists}");

      if (!groupDoc.exists || groupDoc.data() == null) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data()!;
      print("📋 Group data keys: ${groupData.keys.toList()}");

      // Clear existing members
      _members.clear();
      print("🧹 Cleared existing members");

      // Get participants
      final participants = List<String>.from(groupData['participants'] ?? []);
      final admins = List<String>.from(groupData['admins'] ?? []);
      final createdBy = groupData['createdBy']?.toString();

      print("👥 Found participants: $participants");
      print("👑 Admins: $admins");
      print("👑 Created by: $createdBy");

      if (participants.isEmpty) {
        print("⚠️ No participants found");
        isLoading = false;
        notifyListeners();
        return;
      }

      // Load each member
      List<ViewMember> loadedMembers = [];

      for (String participantId in participants) {
        try {
          ViewMember? member = await _loadSingleMember(participantId, admins, createdBy);
          if (member != null) {
            loadedMembers.add(member);
            print("✅ Loaded member: ${member.name} (${member.role})");
          }
        } catch (e) {
          print("❌ Error loading member $participantId: $e");
          // Add basic member data even if detailed loading fails
          loadedMembers.add(_createBasicMember(participantId, admins, createdBy));
        }
      }

      // Sort members (Admins first, then alphabetically)
      loadedMembers.sort((a, b) {
        if (a.role == 'Admin' && b.role != 'Admin') return -1;
        if (b.role == 'Admin' && a.role != 'Admin') return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _members.addAll(loadedMembers);
      filteredMembers = List.from(_members);

      print("✅ ============ LOADING COMPLETE ============");
      print("✅ Total members loaded: ${_members.length}");

    } catch (e) {
      print("❌ Error loading members: $e");
      error = 'Error loading members: ${e.toString()}';
    } finally {
      isLoading = false;
      notifyListeners();
      print("🏁 Loading complete - Members: ${_members.length}");
    }
  }

  Future<ViewMember?> _loadSingleMember(String participantId, List<String> admins, String? createdBy) async {
    print("🔍 Loading member: $participantId");

    // Extract user ID (remove app_user_ prefix if present)
    String userId = participantId;
    if (participantId.startsWith('app_user_')) {
      userId = participantId.substring(9);
    }

    // Determine role
    String role = 'Member';
    if (admins.contains(participantId) || participantId == createdBy) {
      role = 'Admin';
    }

    // Try to get user data from Firebase
    Map<String, dynamic>? userData = await _fetchUserData(participantId, userId);

    String name = _generateDisplayName(participantId, userId, userData);
    String email = _extractEmail(userData) ?? (participantId.contains('@') ? participantId : '');
    String avatarUrl = _extractAvatarUrl(userData);
    bool isOnline = _extractOnlineStatus(userData);

    return ViewMember(
      id: participantId,
      name: name,
      avatarUrl: avatarUrl,
      email: email,
      joinedAt: DateTime.now().toString(),
      isOnline: isOnline,
      role: role,
    );
  }

  Future<Map<String, dynamic>?> _fetchUserData(String participantId, String userId) async {
    // Try multiple approaches to find user data

    // 1. Try participant ID as document ID
    Map<String, dynamic>? userData = await _tryGetDocument(participantId);
    if (userData != null) {
      print("👤 Found user data using participant ID: $participantId");
      return userData;
    }

    // 2. Try numeric user ID as document ID
    if (userId != participantId) {
      userData = await _tryGetDocument(userId);
      if (userData != null) {
        print("👤 Found user data using user ID: $userId");
        return userData;
      }
    }

    // 3. Try querying by id field
    userData = await _tryQuery('id', int.tryParse(userId));
    if (userData != null) {
      print("👤 Found user data by id query: $userId");
      return userData;
    }

    // 4. Try querying by userId field
    userData = await _tryQuery('userId', userId);
    if (userData != null) {
      print("👤 Found user data by userId query: $userId");
      return userData;
    }

    // 5. Try querying by email if it looks like email
    if (participantId.contains('@')) {
      userData = await _tryQuery('email', participantId);
      if (userData != null) {
        print("👤 Found user data by email query: $participantId");
        return userData;
      }
    }

    print("⚠️ No user data found for: $participantId");
    return null;
  }

  Future<Map<String, dynamic>?> _tryGetDocument(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("⚠️ Error getting document $docId: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _tryQuery(String field, dynamic value) async {
    if (value == null) return null;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (e) {
      print("⚠️ Error querying $field = $value: $e");
    }
    return null;
  }

  String _generateDisplayName(String participantId, String userId, Map<String, dynamic>? userData) {
    // Try to get name from user data
    if (userData != null) {
      String? name = _extractName(userData);
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    // Generate default name based on ID format
    if (participantId.startsWith('app_user_')) {
      return 'User $userId';
    } else if (participantId.contains('@')) {
      return participantId.split('@')[0].toUpperCase();
    } else {
      return 'Member $participantId';
    }
  }

  String? _extractName(Map<String, dynamic> userData) {
    final nameFields = ['name', 'displayName', 'full_name', 'fullName', 'firstName'];
    for (String field in nameFields) {
      if (userData[field]?.toString().isNotEmpty == true) {
        return userData[field].toString();
      }
    }
    return null;
  }

  String? _extractEmail(Map<String, dynamic>? userData) {
    if (userData == null) return null;

    final emailFields = ['email', 'emailAddress', 'email_address'];
    for (String field in emailFields) {
      if (userData[field]?.toString().isNotEmpty == true) {
        return userData[field].toString();
      }
    }
    return null;
  }

  String _extractAvatarUrl(Map<String, dynamic>? userData) {
    if (userData == null) return '';

    final imageFields = [
      'photoUrl', 'profilePicture', 'profile_image', 'profileImage',
      'avatar', 'imageUrl', 'picture', 'photo'
    ];

    for (String field in imageFields) {
      String? url = userData[field]?.toString();
      if (url?.isNotEmpty == true &&
          (url!.startsWith('http') || url.startsWith('https'))) {
        return url;
      }
    }
    return '';
  }

  bool _extractOnlineStatus(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // Check various online status patterns
    if (userData['isOnline'] == true || userData['isOnline'] == 'true') return true;
    if (userData['online'] == true || userData['online'] == 'true') return true;
    if (userData['status']?.toString().toLowerCase() == 'online') return true;
    if (userData['userStatus']?.toString().toLowerCase() == 'online') return true;
    return false;
  }

  ViewMember _createBasicMember(String participantId, List<String> admins, String? createdBy) {
    String userId = participantId.startsWith('app_user_')
        ? participantId.substring(9)
        : participantId;

    String role = (admins.contains(participantId) || participantId == createdBy)
        ? 'Admin'
        : 'Member';

    return ViewMember(
      id: participantId,
      name: _generateDisplayName(participantId, userId, null),
      avatarUrl: '',
      email: participantId.contains('@') ? participantId : '',
      joinedAt: DateTime.now().toString(),
      isOnline: false,
      role: role,
    );
  }

  void _filterMembers() {
    String searchTerm = searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      filteredMembers = List.from(_members);
    } else {
      filteredMembers = _members.where((member) =>
      member.name.toLowerCase().contains(searchTerm) ||
          member.id.toLowerCase().contains(searchTerm)
      ).toList();
    }

    print("🔍 Filtered members: ${filteredMembers.length}/${_members.length} (search: '$searchTerm')");
    notifyListeners();
  }

  Future<void> refreshMembers() async {
    print("🔄 Refreshing members...");
    if (groupId != null) {
      await loadMembers();
    }
  }

  ViewMember? getMemberById(String memberId) {
    try {
      return _members.firstWhere((member) => member.id == memberId);
    } catch (e) {
      print("❌ Member not found: $memberId");
      return null;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _groupSubscription?.cancel();
    super.dispose();
  }
}