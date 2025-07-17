// ABOUTME: Service for storing and retrieving conversation history and recordings
// ABOUTME: Provides persistence and management of conversation data and audio files

import 'dart:async';
import 'dart:io';

import '../models/conversation_model.dart';
import '../core/utils/logging_service.dart';
import '../core/utils/exceptions.dart';

/// Service interface for conversation storage and retrieval
abstract class ConversationStorageService {
  /// Get all conversations
  Future<List<Conversation>> getAllConversations();
  
  /// Get conversation by ID
  Future<Conversation?> getConversation(String id);
  
  /// Save a conversation
  Future<void> saveConversation(Conversation conversation);
  
  /// Delete a conversation
  Future<void> deleteConversation(String id);
  
  /// Update conversation
  Future<void> updateConversation(Conversation conversation);
  
  /// Search conversations
  Future<List<Conversation>> searchConversations(String query);
  
  /// Get conversations by date range
  Future<List<Conversation>> getConversationsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  );
  
  /// Stream of conversation updates
  Stream<List<Conversation>> get conversationStream;
}

/// In-memory implementation of conversation storage
/// This is a simple implementation for development/testing
class InMemoryConversationStorageService implements ConversationStorageService {
  static const String _tag = 'InMemoryConversationStorageService';
  
  final LoggingService _logger;
  final List<Conversation> _conversations = [];
  final StreamController<List<Conversation>> _conversationStreamController =
      StreamController<List<Conversation>>.broadcast();
  
  InMemoryConversationStorageService({required LoggingService logger})
      : _logger = logger;

  @override
  Future<List<Conversation>> getAllConversations() async {
    _logger.log(_tag, 'Getting all conversations', LogLevel.debug);
    return List.from(_conversations);
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    _logger.log(_tag, 'Getting conversation: $id', LogLevel.debug);
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _logger.log(_tag, 'Saving conversation: ${conversation.id}', LogLevel.info);
    
    // Remove existing conversation with same ID
    _conversations.removeWhere((c) => c.id == conversation.id);
    
    // Add new conversation
    _conversations.add(conversation);
    
    // Sort by creation date (newest first)
    _conversations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Notify listeners
    _conversationStreamController.add(List.from(_conversations));
  }

  @override
  Future<void> deleteConversation(String id) async {
    _logger.log(_tag, 'Deleting conversation: $id', LogLevel.info);
    
    final removed = _conversations.removeWhere((c) => c.id == id);
    
    if (removed > 0) {
      // Notify listeners
      _conversationStreamController.add(List.from(_conversations));
    }
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    _logger.log(_tag, 'Updating conversation: ${conversation.id}', LogLevel.info);
    
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
      
      // Sort by creation date (newest first)
      _conversations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Notify listeners
      _conversationStreamController.add(List.from(_conversations));
    }
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    _logger.log(_tag, 'Searching conversations: $query', LogLevel.debug);
    
    final lowerQuery = query.toLowerCase();
    
    return _conversations.where((conversation) {
      // Search in title
      if (conversation.title.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      
      // Search in segments
      for (final segment in conversation.segments) {
        if (segment.content.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      
      // Search in participant names
      for (final participant in conversation.participants) {
        if (participant.name.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      
      return false;
    }).toList();
  }

  @override
  Future<List<Conversation>> getConversationsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    _logger.log(_tag, 'Getting conversations by date range: $startDate - $endDate', LogLevel.debug);
    
    return _conversations.where((conversation) {
      return conversation.createdAt.isAfter(startDate) && 
             conversation.createdAt.isBefore(endDate);
    }).toList();
  }

  @override
  Stream<List<Conversation>> get conversationStream => _conversationStreamController.stream;
  
  /// Clean up resources
  Future<void> dispose() async {
    await _conversationStreamController.close();
  }
}