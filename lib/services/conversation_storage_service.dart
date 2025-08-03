// ABOUTME: Service for storing and retrieving conversation history and recordings
// ABOUTME: Provides persistence and management of conversation data and audio files

import 'dart:async';

import '../models/conversation_model.dart';
import '../core/utils/logging_service.dart';

/// Service interface for conversation storage and retrieval
abstract class ConversationStorageService {
  /// Get all conversations
  Future<List<ConversationModel>> getAllConversations();
  
  /// Get conversation by ID
  Future<ConversationModel?> getConversation(String id);
  
  /// Save a conversation
  Future<void> saveConversation(ConversationModel conversation);
  
  /// Delete a conversation
  Future<void> deleteConversation(String id);
  
  /// Update conversation
  Future<void> updateConversation(ConversationModel conversation);
  
  /// Search conversations
  Future<List<ConversationModel>> searchConversations(String query);
  
  /// Get conversations by date range
  Future<List<ConversationModel>> getConversationsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  );
  
  /// Stream of conversation updates
  Stream<List<ConversationModel>> get conversationStream;
}

/// In-memory implementation of conversation storage
/// This is a simple implementation for development/testing
class InMemoryConversationStorageService implements ConversationStorageService {
  static const String _tag = 'InMemoryConversationStorageService';
  
  final LoggingService _logger;
  final List<ConversationModel> _conversations = [];
  final StreamController<List<ConversationModel>> _conversationStreamController =
      StreamController<List<ConversationModel>>.broadcast();
  
  InMemoryConversationStorageService({required LoggingService logger})
      : _logger = logger;

  @override
  Future<List<ConversationModel>> getAllConversations() async {
    _logger.log(_tag, 'Getting all conversations', LogLevel.debug);
    return List.from(_conversations);
  }

  @override
  Future<ConversationModel?> getConversation(String id) async {
    _logger.log(_tag, 'Getting conversation: $id', LogLevel.debug);
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveConversation(ConversationModel conversation) async {
    _logger.log(_tag, 'Saving conversation: ${conversation.id}', LogLevel.info);
    
    // Remove existing conversation with same ID
    _conversations.removeWhere((c) => c.id == conversation.id);
    
    // Add new conversation
    _conversations.add(conversation);
    
    // Sort by creation date (newest first)
    _conversations.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    // Notify listeners
    _conversationStreamController.add(List.from(_conversations));
  }

  @override
  Future<void> deleteConversation(String id) async {
    _logger.log(_tag, 'Deleting conversation: $id', LogLevel.info);
    
    final originalLength = _conversations.length;
    _conversations.removeWhere((c) => c.id == id);
    
    if (_conversations.length < originalLength) {
      // Notify listeners
      _conversationStreamController.add(List.from(_conversations));
    }
  }

  @override
  Future<void> updateConversation(ConversationModel conversation) async {
    _logger.log(_tag, 'Updating conversation: ${conversation.id}', LogLevel.info);
    
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
      
      // Sort by creation date (newest first)
      _conversations.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      // Notify listeners
      _conversationStreamController.add(List.from(_conversations));
    }
  }

  @override
  Future<List<ConversationModel>> searchConversations(String query) async {
    _logger.log(_tag, 'Searching conversations: $query', LogLevel.debug);
    
    final lowerQuery = query.toLowerCase();
    
    return _conversations.where((conversation) {
      // Search in title
      if (conversation.title.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      
      // Search in segments  
      for (final segment in conversation.segments) {
        if (segment.text.toLowerCase().contains(lowerQuery)) {
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
  Future<List<ConversationModel>> getConversationsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    _logger.log(_tag, 'Getting conversations by date range: $startDate - $endDate', LogLevel.debug);
    
    return _conversations.where((conversation) {
      return conversation.startTime.isAfter(startDate) && 
             conversation.startTime.isBefore(endDate);
    }).toList();
  }

  @override
  Stream<List<ConversationModel>> get conversationStream => _conversationStreamController.stream;
  
  /// Clean up resources
  Future<void> dispose() async {
    await _conversationStreamController.close();
  }
}