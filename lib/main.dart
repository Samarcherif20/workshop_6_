import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/client.dart';
import 'connectivity_service.dart';
import 'queue_provider.dart';
import 'room_list_screen.dart';

// MAIN
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProxyProvider<ConnectivityService, QueueProvider>(
          create: (_) => QueueProvider(),
          update: (_, connectivity, queue) =>
              queue!..setConnectivity(connectivity),
        ),
      ],
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const WaitingRoomScreen(),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  final String? roomId;
  
  const WaitingRoomScreen({super.key, this.roomId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set the initial room if provided
    if (widget.roomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<QueueProvider>();
        provider.setCurrentRoom(widget.roomId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityService = context.watch<ConnectivityService>();
    final provider = context.watch<QueueProvider>();

    // ✅ CRITICAL FIX: Use provider.clients which is already filtered
    final filteredClients = provider.clients;
    final currentRoomId = provider.currentRoomId;

    // Get current room name safely
    final currentRoomName = currentRoomId == null 
        ? 'All Rooms' 
        : provider.getRoomName(currentRoomId);

    // Debug output
    print('🏠 UI BUILD - Room: $currentRoomId, Filtered: ${filteredClients.length}');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Waiting Room',
          style: TextStyle(
            color: Color(0xFF4A5568),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Color(0xFF6A89CC)),
        actions: [
          // Room selector dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: currentRoomId,
              hint: const Text(
                'Select Room',
                style: TextStyle(color: Color(0xFF718096)),
              ),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6A89CC)),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'All Rooms',
                    style: TextStyle(color: Color(0xFF4A5568)),
                  ),
                ),
                ...provider.rooms.map((room) {
                  return DropdownMenuItem(
                    value: room['id'] as String?,
                    child: Text(
                      room['name']?.toString() ?? 'Unknown Room',
                      style: const TextStyle(color: Color(0xFF4A5568)),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                print('🔄 DROPDOWN CHANGED: $newValue');
                provider.setCurrentRoom(newValue);
                print('🔄 After change - Provider room: ${provider.currentRoomId}');
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Color(0xFF6A89CC)),
            onPressed: () {
              provider.debugRoomAssignment();
            },
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.list, color: Color(0xFF6A89CC)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoomListScreen(),
                ),
              );
            },
            tooltip: 'View all rooms',
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline Banner
          if (!connectivityService.isOnline)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red[800]!,
                    Colors.red[600]!,
                  ],
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode - Data will sync when connected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Room info card - ONLY SHOW WHEN A ROOM IS SELECTED
          if (currentRoomId != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE3F2FD),
                    Color(0xFFF3E5F5),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.meeting_room, color: const Color(0xFF6A89CC), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentRoomName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredClients.length} client${filteredClients.length == 1 ? '' : 's'} in queue',
                          style: const TextStyle(
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Input Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFF8F9FA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration(
                                  hintText: 'Enter client name',
                                  hintStyle: TextStyle(color: Color(0xFFA0AEC0)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                style: const TextStyle(color: Color(0xFF4A5568)),
                                onSubmitted: (name) {
                                  _addClient(provider, name);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6A89CC),
                                    Color(0xFF4A69BB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30), // Very rounded corners
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6A89CC).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _addClient(provider, _controller.text);
                                },
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text(
                                  'Add Client',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30), // Very rounded corners
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Queue header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ' Current Queue (${filteredClients.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        if (filteredClients.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4CAF50),
                                  Color(0xFF45a049),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30), // Very rounded corners
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => provider.nextClient(),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text(
                                'Next Client',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30), // Very rounded corners
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Client List
                  Expanded(
                    child: filteredClients.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: const Color(0xFFA0AEC0),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No clients in queue',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF718096),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add clients to see them here',
                                  style: TextStyle(
                                    color: Color(0xFFA0AEC0),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredClients.length,
                            itemBuilder: (context, index) {
                              final client = filteredClients[index];
                              final name = client.name;
                              final lat = client.lat;
                              final lng = client.lng;
                              final isSynced = client.isSynced ?? false;
                              final roomName = client.waitingRoomId != null 
                                  ? provider.getRoomName(client.waitingRoomId!)
                                  : 'Not assigned';

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white,
                                          const Color(0xFFF8F9FA),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFE3F2FD),
                                              Color(0xFFF3E5F5),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF6A89CC),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4A5568),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (lat != null && lng != null)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.location_on, size: 14, color: const Color(0xFF718096)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF718096),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Text(
                                            '🏢 $roomName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF718096),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Sync icon in circle (like delete icon)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: isSynced 
                                                ? const Color(0xFF4CAF50).withOpacity(0.1)
                                                : const Color(0xFFF57C00).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                isSynced ? Icons.cloud_done : Icons.cloud_upload,
                                                size: 20,
                                              ),
                                              color: isSynced ? const Color(0xFF4CAF50) : const Color(0xFFF57C00),
                                              onPressed: () {
                                                // Optional: Add sync status info
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isSynced 
                                                        ? '${client.name} is synced with server'
                                                        : '${client.name} is pending sync',
                                                    ),
                                                    backgroundColor: isSynced ? const Color(0xFF4CAF50) : const Color(0xFFF57C00),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Delete icon
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete, size: 20),
                                              color: Colors.red,
                                              onPressed: () {
                                                _showDeleteDialog(context, client);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to add client
  void _addClient(QueueProvider provider, String name) async {
    if (name.trim().isNotEmpty) {
      final result = await provider.addClient(name.trim());
      _controller.clear();
      
      if (result != null) {
        final roomId = result['roomId'];
        final roomName = result['roomName'];
        
        // ✅ AUTO-REDIRECT: Switch to the assigned room
        provider.setCurrentRoom(roomId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "$name" added to $roomName'),
            backgroundColor: const Color(0xFF6A89CC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        
        print('🔄 Auto-redirected to room: $roomName ($roomId)');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client "$name" added to queue'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8F9FA),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Remove Client',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to remove ${client.name} from the queue?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF718096),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.red,
                              Color(0xFFD32F2F),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<QueueProvider>().removeClient(client.id);
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${client.name} removed from queue'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}