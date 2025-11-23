import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'queue_provider.dart';
import 'main.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QueueProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Waiting Rooms', style: TextStyle(color: Color(0xFF4A5568))),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: IconThemeData(color: Color(0xFF6A89CC)),
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: Color(0xFF6A89CC)),
            onPressed: () {
              provider.debugRoomAssignment();
              provider.checkDatabaseState();
              
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
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
                        Icon(Icons.analytics, size: 40, color: Color(0xFF6A89CC)),
                        const SizedBox(height: 16),
                        Text(
                          'Debug Info',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Rooms: ${provider.rooms.length}'),
                              Text('Total Clients: ${provider.allClients.length}'),
                              const SizedBox(height: 16),
                              Text('Room Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                              ...provider.rooms.map((room) {
                                final clientCount = provider.getClientsByRoom(room['id'] as String?).length;
                                return Text('• ${room['name']}: $clientCount clients');
                              }).toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6A89CC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            tooltip: 'Debug Info',
          ),
        ],
      ),
      backgroundColor: Color(0xFFF5F5F5),
      body: provider.rooms.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: Color(0xFF6A89CC)),
            )
          : Column(
              children: [
                // Summary card with pastel colors
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
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
                        child: Icon(Icons.analytics, color: Color(0xFF6A89CC), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Queue Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.rooms.length} rooms • ${provider.allClients.length} total clients',
                              style: TextStyle(
                                color: Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Rooms list
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.rooms.length,
                    itemBuilder: (context, index) {
                      final room = provider.rooms[index];
                      final roomId = room['id'] as String;
                      final roomName = room['name'] ?? 'Unknown Room';
                      final roomClients = provider.getClientsByRoom(roomId);
                      final clientCount = roomClients.length;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFE3F2FD),
                                  Color(0xFFF3E5F5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.meeting_room,
                              color: Color(0xFF6A89CC),
                              size: 28,
                            ),
                          ),
                          title: Text(
                            roomName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (room['latitude'] != null && room['longitude'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, size: 12, color: Color(0xFF718096)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${room['latitude']?.toStringAsFixed(4)}, ${room['longitude']?.toStringAsFixed(4)}',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                '$clientCount client${clientCount == 1 ? '' : 's'} in queue',
                                style: TextStyle(
                                  color: clientCount > 0 ? Color(0xFFF57C00) : Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'ID: ${roomId.substring(0, 8)}...',
                                style: TextStyle(fontSize: 10, color: Color(0xFFA0AEC0)),
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF6A89CC)),
                          onTap: () {
                            print('🎯 Navigating to room: $roomId - $roomName');
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WaitingRoomScreen(roomId: roomId),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}