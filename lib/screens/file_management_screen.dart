import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class FileManagementScreen extends StatefulWidget {
  const FileManagementScreen({super.key});

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  List<File> _audioFiles = [];
  bool _isInitialized = false;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadAudioFiles();
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.openPlayer();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
    }
  }

  Future<void> _loadAudioFiles() async {
    try {
      final directory = Directory.systemTemp;
      final files = directory
          .listSync()
          .where((file) => 
              file is File && 
              file.path.contains('helix_') && 
              file.path.endsWith('.wav'))
          .cast<File>()
          .toList();
      
      // Sort by modification time (newest first)
      files.sort((a, b) => 
          b.statSync().modified.compareTo(a.statSync().modified));
      
      setState(() {
        _audioFiles = files;
      });
    } catch (e) {
      debugPrint('Failed to load audio files: $e');
    }
  }

  Future<void> _playPauseAudio(String filePath) async {
    if (!_isInitialized) return;

    try {
      if (_isPlaying && _currentlyPlayingPath == filePath) {
        // Pause current playback
        await _player.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Stop current playback if playing different file
        if (_isPlaying) {
          await _player.stopPlayer();
        }
        
        // Start new playback
        await _player.startPlayer(
          fromURI: filePath,
          whenFinished: () {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingPath = null;
            });
          },
        );
        
        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = filePath;
        });
      }
    } catch (e) {
      debugPrint('Failed to play audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  Future<void> _stopPlayback() async {
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingPath = null;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Files'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAudioFiles,
          ),
        ],
      ),
      body: _audioFiles.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No recordings found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start recording to see your files here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Playback controls if currently playing
                if (_isPlaying && _currentlyPlayingPath != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.music_note, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Playing: ${_currentlyPlayingPath!.split('/').last}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: _stopPlayback,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // File list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _audioFiles.length,
                    itemBuilder: (context, index) {
                      final file = _audioFiles[index];
                      final stat = file.statSync();
                      final isCurrentlyPlaying = _currentlyPlayingPath == file.path;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying 
                                  ? Colors.green.shade100 
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              isCurrentlyPlaying && _isPlaying 
                                  ? Icons.pause 
                                  : Icons.play_arrow,
                              color: isCurrentlyPlaying 
                                  ? Colors.green.shade700 
                                  : Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            file.path.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(stat.modified),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              Text(
                                'Size: ${_formatFileSize(stat.size)}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteFile(file);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _playPauseAudio(file.path),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _deleteFile(File file) async {
    try {
      // Stop playback if this file is currently playing
      if (_currentlyPlayingPath == file.path && _isPlaying) {
        await _stopPlayback();
      }
      
      await file.delete();
      await _loadAudioFiles(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
      }
    } catch (e) {
      debugPrint('Failed to delete file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: $e')),
        );
      }
    }
  }
}