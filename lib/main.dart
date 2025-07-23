import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';

void main() {
  runApp(const LanscanApp());
}

class LanscanApp extends StatelessWidget {
  const LanscanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  SSHClient? _sshClient;
  String _sshOutput = '';
  bool _isConnected = false;

  static final List<String> _screenNames = [
    'Devices',
    'Files',
    'System Info',
    'Tasks',
    'Terminal',
  ];
  static final List<Widget> _screens = <Widget>[];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      DeviceListScreen(onConnect: _connectSSH, isConnected: _isConnected),
      FileManagementScreen(sshClient: _sshClient, isConnected: _isConnected),
      SystemInfoScreen(),
      TaskManagerScreen(),
      LiveTerminalScreen(
        sshClient: _sshClient,
        sshOutput: _sshOutput,
        onSendCommand: _sendSSHCommand,
        isConnected: _isConnected,
      ),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _connectSSH(
    String host,
    String username,
    String password,
  ) async {
    try {
      final socket = await SSHSocket.connect(host, 22);
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      setState(() {
        _sshClient = client;
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SSH Connection failed: $e')));
    }
  }

  Future<void> _sendSSHCommand(String command) async {
    if (_sshClient == null) return;
    try {
      final session = await _sshClient!.execute(command);
      final output = await session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      _sshOutput += '\n$output';
    } catch (e) {
      _sshOutput += '\nError: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LANScan')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Available Screens:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...List.generate(
            _screenNames.length,
            (i) => ListTile(
              title: Text(_screenNames[i]),
              trailing: i == _selectedIndex
                  ? const Icon(Icons.arrow_right)
                  : null,
              onTap: () => setState(() => _selectedIndex = i),
            ),
          ),
          const Divider(),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'System Info'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tasks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// 1. Device List Screen
class DeviceListScreen extends StatelessWidget {
  final Function(String, String, String) onConnect;
  final bool isConnected;
  const DeviceListScreen({
    super.key,
    required this.onConnect,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final hostController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Device List (Scan & Connect via SSH)'),
          const SizedBox(height: 16),
          TextField(
            controller: hostController,
            decoration: const InputDecoration(labelText: 'Host'),
          ),
          TextField(
            controller: userController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: passController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              onConnect(
                hostController.text,
                userController.text,
                passController.text,
              );
            },
            child: Text(isConnected ? 'Connected' : 'Connect SSH'),
          ),
        ],
      ),
    );
  }
}

// 2. File Management Screen
class FileManagementScreen extends StatelessWidget {
  final SSHClient? sshClient;
  final bool isConnected;
  const FileManagementScreen({
    super.key,
    required this.sshClient,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final fileController = TextEditingController();
    final contentController = TextEditingController();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('File Management (Upload, Download, Edit)'),
          const SizedBox(height: 16),
          TextField(
            controller: fileController,
            decoration: const InputDecoration(labelText: 'File Path'),
          ),
          TextField(
            controller: contentController,
            decoration: const InputDecoration(labelText: 'File Content'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isConnected && sshClient != null
                ? () async {
                    // Edit file
                    await sshClient!.execute(
                      'echo "${contentController.text}" > ${fileController.text}',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File edited!')),
                    );
                  }
                : null,
            child: const Text('Edit File'),
          ),
          ElevatedButton(
            onPressed: isConnected && sshClient != null
                ? () async {
                    // Download file
                    final session = await sshClient!.execute(
                      'cat ${fileController.text}',
                    );
                    final output = await session.stdout
                        .cast<List<int>>()
                        .transform(utf8.decoder)
                        .join();
                    contentController.text = output;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File downloaded!')),
                    );
                  }
                : null,
            child: const Text('Download File'),
          ),
          ElevatedButton(
            onPressed: isConnected && sshClient != null
                ? () async {
                    // Move file (example: move to /tmp)
                    await sshClient!.execute('mv ${fileController.text} /tmp/');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File moved to /tmp!')),
                    );
                  }
                : null,
            child: const Text('Move File'),
          ),
        ],
      ),
    );
  }
}

// 3. System Info Screen
class SystemInfoScreen extends StatelessWidget {
  const SystemInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder for system info UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('System Info & Device Details'),
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: '192.168.1.10',
            items: const [
              DropdownMenuItem(
                value: '192.168.1.10',
                child: Text('192.168.1.10'),
              ),
              DropdownMenuItem(
                value: '192.168.1.11',
                child: Text('192.168.1.11'),
              ),
            ],
            onChanged: (value) {},
          ),
          const SizedBox(height: 16),
          const Text('CPU: ARMv7\nRAM: 1GB\nOS: Linux'),
        ],
      ),
    );
  }
}

// 4. Task Manager Screen
class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder for task manager UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Task Manager (View & Kill Tasks)'),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('sshd'),
            subtitle: const Text('PID: 1234'),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Kill'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('python3'),
            subtitle: const Text('PID: 5678'),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Kill'),
            ),
          ),
        ],
      ),
    );
  }
}

// 5. Live Terminal Screen
class LiveTerminalScreen extends StatelessWidget {
  final SSHClient? sshClient;
  final String sshOutput;
  final Function(String) onSendCommand;
  final bool isConnected;
  const LiveTerminalScreen({
    super.key,
    required this.sshClient,
    required this.sshOutput,
    required this.onSendCommand,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final commandController = TextEditingController();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Live Terminal (SSH Client)'),
          const SizedBox(height: 16),
          TextField(
            controller: commandController,
            decoration: const InputDecoration(labelText: 'Command'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isConnected && sshClient != null
                ? () {
                    onSendCommand(commandController.text);
                  }
                : null,
            child: const Text('Send Command'),
          ),
          const SizedBox(height: 16),
          Text(sshOutput),
        ],
      ),
    );
  }
}
