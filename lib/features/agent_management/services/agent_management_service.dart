import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class AgentManagementService {
  final Dio _dio = ApiClient().dio;

  // 1. Get My Agents Only
  Future<List<AgentModel>> getAllAgents() async {
    try {
      final response = await _dio.get('/agent/all-agents');

      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => AgentModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLog.e('agents', "Error fetching agents: $e");
      return [];
    }
  }

  // ⭐️ 2. Get Available Plans
  Future<List<dynamic>> getPlans() async {
    try {
      final response = await _dio.get('/agent/plans');
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      AppLog.e('agents', "Error fetching plans: $e");
      return [];
    }
  }

  // 3. Create Agent
  Future<bool> createAgent(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/agent/create-agent', data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      AppLog.e('agents', "Create Error: ${e.response?.data}");
      return false;
    }
  }

  // 4. Update Agent
  Future<bool> updateAgent(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/agent/update-agent/$id', data: data);
      return response.statusCode == 200;
    } on DioException catch (e) {
      AppLog.e('agents', "Update Error: ${e.response?.data}");
      return false;
    }
  }

  // 5. Delete Agent
  Future<bool> deleteAgent(int id) async {
    try {
      final response = await _dio.delete('/agent/delete-agent/$id');
      return response.statusCode == 200;
    } catch (e) {
      AppLog.e('agents', "Delete Error: $e");
      return false;
    }
  }
}
