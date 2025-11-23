import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/client.dart';
import 'package:uuid/uuid.dart';
import 'local_queue_service.dart';
import 'geolocation_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'location_utils.dart';
import 'connectivity_service.dart';

class QueueProvider extends ChangeNotifier {
  // ========== PROPRIÉTÉS ==========
  final List<Client> _allClients = [];
  final List<Map<String, dynamic>> _rooms = [];
  String? _currentRoomId;
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalQueueService _localDb = LocalQueueService();
  final GeolocationService _geoService;
  late RealtimeChannel _subscription;
  ConnectivityService? _connectivity;

  // ========== GETTERS ==========
  List<Client> get clients {
    print('🎯 [FILTER] ===== FILTERING STARTED =====');
    print('🎯 [FILTER] Current room: "$_currentRoomId"');
    print('🎯 [FILTER] Total clients: ${_allClients.length}');
    
    if (_currentRoomId == null) {
      print('🎯 [FILTER] No room selected - returning ALL clients');
      return _allClients;
    }
    
    final filteredClients = <Client>[];
    
    for (var client in _allClients) {
      final clientRoomId = client.waitingRoomId;
      final currentRoomId = _currentRoomId;
      
      print('🎯 [FILTER] Checking client: ${client.name}');
      print('🎯 [FILTER]   Client room ID: $clientRoomId');
      print('🎯 [FILTER]   Current room ID: $currentRoomId');
      
      if (clientRoomId == currentRoomId) {
        print('🎯 [FILTER]   ✅ MATCH - Adding to filtered list');
        filteredClients.add(client);
      } else {
        print('🎯 [FILTER]   ❌ NO MATCH - Skipping');
      }
    }
    
    print('🎯 [FILTER] ===== FILTERING COMPLETE =====');
    print('🎯 [FILTER] Result: ${filteredClients.length} clients');
    
    return filteredClients;
  }
  
  List<Client> get allClients => _allClients;
  List<Map<String, dynamic>> get rooms => _rooms;
  String? get currentRoomId => _currentRoomId;

  // ========== CONSTRUCTEUR ET INITIALISATION ==========
  QueueProvider({GeolocationService? geoService})
      : _geoService = geoService ?? GeolocationService() {
    print('🚀 QueueProvider initialized');
    initialize();
  }

  void setConnectivity(ConnectivityService connectivity) {
    _connectivity = connectivity;
    notifyListeners();
  }

  Future<void> initialize() async {
    print('🔄 QueueProvider initializing...');
    await _loadQueue();
    _setupRealtimeSubscription();
    _monitorConnectivity();
    await fetchWaitingRooms();
    
    // ADD DATABASE CHECK
    await checkDatabaseState();
    await checkClientRoomAssignments();
  }

  // ========== GESTION DES SALLES ==========
  void setCurrentRoom(String? roomId) {
    print('🎯 [ROOM CHANGE] Changing room: "$_currentRoomId" → "$roomId"');
    _currentRoomId = roomId;
    
    // Enhanced debugging
    if (roomId != null) {
      try {
        final roomName = getRoomName(roomId);
        print('🎯 [ROOM CHANGE] Selected: $roomName ($roomId)');
      } catch (e) {
        print('❌ [ROOM CHANGE] Could not find room name for ID: $roomId');
      }
    } else {
      print('🎯 [ROOM CHANGE] Showing ALL rooms');
    }
    
    print('🔍 [ROOM CHANGE] Clients count after change: ${clients.length}');
    
    notifyListeners();
  }

  void clearCurrentRoom() {
    _currentRoomId = null;
    notifyListeners();
  }

  String getRoomName(String roomId) {
    try {
      final room = _rooms.firstWhere((room) => room['id'] == roomId);
      return room['name'] ?? 'Unknown Room';
    } catch (e) {
      return 'Unknown Room';
    }
  }

  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    try {
      final response = await _supabase
          .from('waiting_rooms')
          .select()
          .eq('id', roomId)
          .single();
      return response;
    } catch (e) {
      print('❌ Erreur getRoomById: $e');
      return null;
    }
  }

  List<Client> getClientsByRoom(String? roomId) {
    if (roomId == null) return _allClients;
    return _allClients.where((client) => client.waitingRoomId == roomId).toList();
  }

  Future<Map<String, int>> getRoomCounts() async {
    try {
      final response = await _supabase
          .from('clients')
          .select('waiting_room_id');
      
      final counts = <String, int>{};
      for (var client in response) {
        final roomId = client['waiting_room_id'] as String?;
        if (roomId != null) {
          counts[roomId] = (counts[roomId] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      print('❌ Erreur getRoomCounts: $e');
      return {};
    }
  }

  // ========== CHARGEMENT DES DONNÉES ==========
  Future<void> _loadQueue() async {
    print('📥 Loading queue from local database...');
    final localClients = await _localDb.getClients();
    _allClients
      ..clear()
      ..addAll(localClients.map((map) => Client.fromMap(map)));
    notifyListeners();

    await _syncLocalToRemote();
    await _fetchInitialClients();
  }

  Future<void> _fetchInitialClients() async {
    try {
      print('📥 Fetching initial clients from Supabase...');
      final data = await _supabase.from('clients').select().order('created_at');
      
      // ADD COMPREHENSIVE DEBUGGING
      print('🔍 RAW DATA FROM SUPABASE:');
      print('🔍 Data type: ${data.runtimeType}');
      print('🔍 Data length: ${data.length}');
      
      _allClients.clear();
      
      for (var i = 0; i < data.length; i++) {
        try {
          final item = data[i];
          print('🔍 Client $i: $item');
          
          final clientMap = item as Map<String, dynamic>;
          final client = Client.fromMap(clientMap);
          
          print('🔍 Parsed Client $i:');
          print('   👤 Name: ${client.name}');
          print('   🆔 ID: ${client.id}');
          print('   🏢 Waiting Room ID: ${client.waitingRoomId}');
          print('   📍 Lat: ${client.lat}, Lng: ${client.lng}');
          print('   🕐 Created: ${client.createdAt}');
          print('   ☁️ Synced: ${client.isSynced}');
          
          _allClients.add(client);
        } catch (e) {
          print('❌ Error converting client $i: $e - Data: ${data[i]}');
        }
      }
      
      _allClients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
      print('📥 Successfully loaded ${_allClients.length} clients from Supabase');
      
      // ADD DEBUG CALL
      debugRoomAssignment();
      
    } catch (e) {
      print('❌ Error in _fetchInitialClients: $e');
    }
  }

  Future<void> fetchWaitingRooms() async {
    try {
      print('🏥 Fetching waiting rooms...');
      final response = await _supabase.from('waiting_rooms').select();
      
      print('🔍 RAW ROOMS DATA FROM SUPABASE:');
      print('🔍 Rooms data type: ${response.runtimeType}');
      print('🔍 Rooms data length: ${response.length}');
      
      _rooms.clear();
      _rooms.addAll(List<Map<String, dynamic>>.from(response));
      notifyListeners();
      
      print('✅ Successfully loaded ${_rooms.length} waiting rooms:');
      for (var i = 0; i < _rooms.length; i++) {
        final room = _rooms[i];
        print('   🏢 Room $i: ${room['name']}');
        print('      🆔 ID: ${room['id']}');
        print('      📍 Lat: ${room['latitude']}, Lng: ${room['longitude']}');
      }
      
      // ADD DEBUG CALL
      debugRoomAssignment();
      
    } catch (e) {
      debugPrint('❌ Error in fetchWaitingRooms: $e');
    }
  }

  // ========== GESTION DES CLIENTS ==========
  Future<Map<String, String>?> addClient(String name) async {
    if (name.trim().isEmpty) return null;

    try {
      print('➕ ADDING CLIENT: $name');
      final position = await _geoService.getCurrentPosition();
      final roomInfo = await _findNearestRoom(
          position?.latitude ?? 0.0, position?.longitude ?? 0.0);

      if (roomInfo == null) {
        print('❌ No room found for client');
        return null;
      }

      final roomId = roomInfo['roomId'] as String;
      final roomName = roomInfo['roomName'] as String;

      print('📍 Client will be assigned to:');
      print('   🏢 Room Name: $roomName');
      print('   🆔 Room ID: $roomId');

      final newClient = {
        'id': const Uuid().v4(),
        'name': name.trim(),
        'lat': position?.latitude,
        'lng': position?.longitude,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
        'waiting_room_id': roomId,
      };

      print('📝 Creating client with data:');
      print('   👤 Name: ${newClient['name']}');
      print('   🆔 ID: ${newClient['id']}');
      print('   🏢 Waiting Room ID: ${newClient['waiting_room_id']}');
      print('   📍 Lat: ${newClient['lat']}, Lng: ${newClient['lng']}');

      await _localDb.insertClientLocally(newClient);
      
      final clientObj = Client.fromMap(newClient);
      _allClients.add(clientObj);
      _allClients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();

      print('✅ CLIENT ADDED SUCCESSFULLY:');
      print('   👤 Name: ${clientObj.name}');
      print('   🆔 ID: ${clientObj.id}');
      print('   🏢 Waiting Room ID: ${clientObj.waitingRoomId}');

      unawaited(_syncAddClientToRemote(newClient));

      // ✅ RETURN ROOM INFO FOR AUTO-REDIRECT
      return {
        'roomId': roomId,
        'roomName': roomName,
      };

    } catch (e) {
      print('❌ Failed to add client: $e');
      return null;
    }
  }

  Future<void> removeClient(String id) async {
    try {
      print('🗑️ Removing client: $id');
      await _supabase.from('clients').delete().match({'id': id});
      _allClients.removeWhere((client) => client.id == id);
      await _localDb.removeClient(id);
      notifyListeners();
      print('✅ Client removed: $id');
    } catch (e) {
      print('❌ Failed to remove client: $e');
      // Still remove from local list even if remote fails
      _allClients.removeWhere((client) => client.id == id);
      await _localDb.removeClient(id);
      notifyListeners();
    }
  }

  Future<void> nextClient() async {
    final currentClients = clients;
    
    if (currentClients.isEmpty) {
      print('❌ Queue is empty for this room!');
      return;
    }

    final firstClient = currentClients.first;
    print('⏭️ Calling next client: ${firstClient.name}');
    await removeClient(firstClient.id);
  }

  // ========== SYNCHRONISATION ==========
  Future<void> _syncLocalToRemote() async {
    if (_connectivity == null || !_connectivity!.isOnline) return;

    final unsynced = await _localDb.getUnsyncedClients();
    print('🔄 Syncing ${unsynced.length} unsynced clients to remote...');
    
    for (var clientMap in unsynced) {
      try {
        final client = Client.fromMap(clientMap);

        final remoteClient = Map<String, dynamic>.from(clientMap)
          ..remove('is_synced')
          ..['is_synced'] = true;

        final response = await _supabase
            .from('clients')
            .upsert(remoteClient, onConflict: 'id')
            .select();

        if (response.isNotEmpty) {
          await _localDb.markClientAsSynced(client.id);

          final index = _allClients.indexWhere((c) => c.id == client.id);
          if (index != -1) {
            _allClients[index] = Client(
              id: client.id,
              name: client.name,
              createdAt: client.createdAt,
              lat: client.lat,
              lng: client.lng,
              isSynced: true,
              waitingRoomId: client.waitingRoomId,
            );
            notifyListeners();
          }
          print('✅ Client synced: ${client.name}');
        }
      } catch (e) {
        print('❌ Sync failed for ${clientMap['id']}: $e');
      }
    }
  }

  Future<void> _syncAddClientToRemote(Map<String, dynamic> clientMap) async {
    if (_connectivity == null || !_connectivity!.isOnline) return;

    try {
      final client = Client.fromMap(clientMap);

      final remoteClient = Map<String, dynamic>.from(clientMap)
        ..remove('is_synced')
        ..['is_synced'] = true;

      final response =
          await _supabase.from('clients').upsert(remoteClient).select();

      if (response.isNotEmpty) {
        await _localDb.markClientAsSynced(client.id);

        final index = _allClients.indexWhere((c) => c.id == client.id);
        if (index != -1) {
          _allClients[index] = Client(
            id: client.id,
            name: client.name,
            createdAt: client.createdAt,
            lat: client.lat,
            lng: client.lng,
            isSynced: true,
            waitingRoomId: client.waitingRoomId,
          );
          notifyListeners();
        }

        print('✅ Client synced to remote: ${client.name}');
      }
    } catch (e) {
      print('❌ Failed to sync client to remote: $e');
    }
  }

  // ========== GÉOLOCALISATION ==========
  Future<Map<String, String>?> _findNearestRoom(double clientLat, double clientLng) async {
    if (_rooms.isEmpty) await fetchWaitingRooms();

    if (clientLat == 0.0 && clientLng == 0.0) {
      print('📍 Géolocalisation non disponible - utilisation salle par défaut');
      if (_rooms.isNotEmpty) {
        final defaultRoom = _rooms.first;
        return {
          'roomId': defaultRoom['id'] as String,
          'roomName': defaultRoom['name'] as String,
        };
      }
      return null;
    }

    double minDistance = double.infinity;
    Map<String, String>? nearestRoom;

    for (var room in _rooms) {
      final roomLat = room['latitude'] as double;
      final roomLng = room['longitude'] as double;
      final distance = calculateDistance(clientLat, clientLng, roomLat, roomLng);

      if (distance < minDistance) {
        minDistance = distance;
        nearestRoom = {
          'roomId': room['id'] as String,
          'roomName': room['name'] as String,
        };
      }
    }
    
    print('📍 Salle la plus proche: ${nearestRoom?['roomName']} (distance: ${minDistance.toStringAsFixed(2)} km)');
    return nearestRoom;
  }

  // ========== CONNECTIVITÉ ET TEMPS RÉEL ==========
  void _setupRealtimeSubscription() {
    _subscription = _supabase.channel('public:clients')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          try {
            print('📡 Realtime INSERT received: $payload');
            final newClient = Client.fromMap(payload.newRecord);
            final exists = _allClients.any((c) => c.id == newClient.id);
            if (!exists) {
              print('📡 Adding new client from realtime: ${newClient.name}');
              final localClient = Map<String, dynamic>.from(payload.newRecord)
                ..['is_synced'] = 1;
              await _localDb.insertClientLocally(localClient);
              _allClients.add(newClient);
              _allClients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              notifyListeners();
              print('➕ Client inserted: ${newClient.name}');
            }
          } catch (e) {
            print('❌ Error handling insert: $e');
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          try {
            final deletedId = payload.oldRecord['id'] as String;
            _allClients.removeWhere((c) => c.id == deletedId);
            await _localDb.removeClient(deletedId);
            notifyListeners();
            print('🗑️ Client deleted: $deletedId');
          } catch (e) {
            print('❌ Error handling delete: $e');
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          try {
            final updatedClient = Client.fromMap(payload.newRecord);
            final index = _allClients.indexWhere((c) => c.id == updatedClient.id);
            if (index != -1) {
              _allClients[index] = updatedClient;
              notifyListeners();
              print('✏️ Client updated: ${updatedClient.name}');
            }
          } catch (e) {
            print('❌ Error handling update: $e');
          }
        },
      )
      ..subscribe((status, error) {
        print('📡 Subscription status: $status');
        if (error != null) {
          print('❌ Subscription error: $error');
        }
      });
    
    print('📡 Realtime subscription setup complete');
  }

  void _monitorConnectivity() {
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print('🔌 Internet reconnected — retrying sync');
        _syncLocalToRemote();
      }
    });
  }

  // ========== MÉTHODES DE DÉBOGAGE ==========
  void debugRoomAssignment() {
    print('\n=== 🐛 DEBUG ROOM ASSIGNMENT ===');
    print('📊 Total rooms: ${_rooms.length}');
    print('📊 Total clients: ${_allClients.length}');
    print('🎯 Current room filter: $_currentRoomId');
    
    // Print all rooms
    print('\n🏢 ALL ROOMS:');
    for (var room in _rooms) {
      final roomId = room['id'] as String;
      final roomName = room['name'] as String;
      final clientsInRoom = _allClients.where((c) => c.waitingRoomId == roomId).length;
      print('   • $roomName (ID: ${roomId.substring(0, 8)}...) → $clientsInRoom clients');
    }
    
    // Print all clients and their room assignments
    print('\n👤 ALL CLIENTS:');
    for (var client in _allClients) {
      final roomName = client.waitingRoomId != null 
          ? getRoomName(client.waitingRoomId!) 
          : 'No room assigned';
      final matchesCurrent = _currentRoomId == null || client.waitingRoomId == _currentRoomId;
      final status = matchesCurrent ? '✅' : '❌';
      print('   $status ${client.name} → Room: $roomName (ID: ${client.waitingRoomId?.substring(0, 8)}...)');
    }
    
    // Count clients per room
    final roomCounts = <String, int>{};
    int clientsWithoutRoom = 0;
    
    for (var client in _allClients) {
      final roomId = client.waitingRoomId;
      if (roomId != null) {
        roomCounts[roomId] = (roomCounts[roomId] ?? 0) + 1;
      } else {
        clientsWithoutRoom++;
      }
    }
    
    print('\n📊 CLIENTS PER ROOM:');
    roomCounts.forEach((roomId, count) {
      final roomName = getRoomName(roomId);
      print('   • $roomName: $count clients');
    });
    print('   • No room assigned: $clientsWithoutRoom clients');
    
    print('=== END DEBUG ===\n');
  }

  void testFilteringManually() {
    print('\n=== 🧪 MANUAL FILTER TEST ===');
    
    if (_rooms.isEmpty) {
      print('❌ No rooms available');
      return;
    }
    
    // Test each room
    for (var room in _rooms) {
      final roomId = room['id'] as String;
      final roomName = room['name'] as String;
      
      print('\n🧪 Testing room: $roomName ($roomId)');
      
      // Manually filter clients for this room
      final filteredClients = _allClients.where((client) {
        return client.waitingRoomId == roomId;
      }).toList();
      
      print('🧪 Manual filter result: ${filteredClients.length} clients');
      
      for (var client in filteredClients) {
        print('   ✅ ${client.name} → Room: ${client.waitingRoomId}');
      }
    }
    
    print('=== END MANUAL TEST ===\n');
  }

  Future<void> checkDatabaseState() async {
    try {
      print('\n=== 🗃️ DATABASE STATE CHECK ===');
      
      // Check rooms
      final roomsData = await _supabase.from('waiting_rooms').select();
      print('🏢 Rooms in database: ${roomsData.length}');
      for (var room in roomsData) {
        print('   • ${room['name']} (ID: ${room['id']})');
      }
      
      // Check clients with room assignments
      final clientsData = await _supabase.from('clients').select('id, name, waiting_room_id');
      print('👤 Clients in database: ${clientsData.length}');
      
      int clientsWithRoom = 0;
      int clientsWithoutRoom = 0;
      
      for (var client in clientsData) {
        final roomId = client['waiting_room_id'];
        if (roomId != null) {
          clientsWithRoom++;
          print('   ✅ ${client['name']} → Room: $roomId');
        } else {
          clientsWithoutRoom++;
          print('   ❌ ${client['name']} → No room assigned');
        }
      }
      
      print('📊 Summary: $clientsWithRoom with rooms, $clientsWithoutRoom without rooms');
      print('=== END DATABASE CHECK ===\n');
      
    } catch (e) {
      print('❌ Error checking database state: $e');
    }
  }

  Future<void> checkClientRoomAssignments() async {
    try {
      print('\n=== 🗃️ CLIENT ROOM ASSIGNMENT CHECK ===');
      
      // Get all clients with their room assignments
      final clientsData = await _supabase
          .from('clients')
          .select('id, name, waiting_room_id');
      
      print('👤 CLIENTS IN DATABASE: ${clientsData.length}');
      
      for (var client in clientsData) {
        final name = client['name'];
        final roomId = client['waiting_room_id'];
        final hasRoom = roomId != null;
        
        if (hasRoom) {
          print('   ✅ $name → Room ID: $roomId');
          
          // Check if this room ID exists in our rooms list
          final roomExists = _rooms.any((room) => room['id'] == roomId);
          if (!roomExists) {
            print('   ⚠️  WARNING: Room ID $roomId does not exist in rooms list!');
          }
        } else {
          print('   ❌ $name → NO ROOM ASSIGNED');
        }
      }
      
      print('=== END ASSIGNMENT CHECK ===\n');
    } catch (e) {
      print('❌ Error checking client assignments: $e');
    }
  }

  // ========== MÉTHODES PUBLIQUES ==========
  Future<void> refreshData() async {
    print('🔄 Manual refresh triggered');
    await fetchWaitingRooms();
    await _fetchInitialClients();
  }

  // ========== DISPOSE ==========
  @override
  void dispose() {
    _supabase.removeChannel(_subscription);
    super.dispose();
  }
}