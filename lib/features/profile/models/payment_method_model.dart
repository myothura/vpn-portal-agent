import 'package:vpn_agent_app/core/api/api_config.dart';

class PaymentMethod {
  String id;
  String bankName;
  String accountName;
  String accountNumber;
  String? qrCodeUrl;
  String? localImagePath;

  PaymentMethod({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.qrCodeUrl,
    this.localImagePath,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id']?.toString() ?? '',
      bankName: json['bank_name'] ?? '',
      accountName: json['account_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      qrCodeUrl: ApiConfig.resolveMediaUrl(json['qr_code_full_url']),
    );
  }

  // ⭐️ Hive အတွက် ဒါလေးလိုပါတယ်
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': accountNumber,
      'qr_code_full_url': qrCodeUrl,
      // localImagePath က ယာယီမို့ သိမ်းစရာမလိုပါ
    };
  }
}
