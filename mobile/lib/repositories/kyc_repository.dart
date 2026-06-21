import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../utils/multipart_image.dart';

class KycRepository {
  KycRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>?> fetchMyApplication() async {
    final r = await _api.get<Map<String, dynamic>>('/kyc/me');
    if (r.data == null) return null;
    return Map<String, dynamic>.from(r.data!);
  }

  Future<Map<String, dynamic>> apply({
    required String businessName,
    required String businessType,
    String? rccm,
    String? taxId,
    String? legalRepresentative,
    String? businessAddress,
    String? contactPhone,
    String? applicantNote,
    Uint8List? docRccmBytes,
    String? docRccmFilename,
    Uint8List? docTaxBytes,
    String? docTaxFilename,
    Uint8List? docIdBytes,
    String? docIdFilename,
    Uint8List? docShopBytes,
    String? docShopFilename,
  }) async {
    final fields = <String, dynamic>{
      'business_name': businessName,
      'business_type': businessType,
      if (rccm != null && rccm.isNotEmpty) 'rccm': rccm,
      if (taxId != null && taxId.isNotEmpty) 'tax_id': taxId,
      if (legalRepresentative != null && legalRepresentative.isNotEmpty)
        'legal_representative': legalRepresentative,
      if (businessAddress != null && businessAddress.isNotEmpty) 'business_address': businessAddress,
      if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
      if (applicantNote != null && applicantNote.isNotEmpty) 'applicant_note': applicantNote,
    };

    if (docRccmBytes != null && docRccmBytes.isNotEmpty) {
      fields['doc_rccm'] = buildImageMultipart(
        bytes: docRccmBytes,
        filename: docRccmFilename ?? 'rccm.jpg',
      );
    }
    if (docTaxBytes != null && docTaxBytes.isNotEmpty) {
      fields['doc_tax'] = buildImageMultipart(
        bytes: docTaxBytes,
        filename: docTaxFilename ?? 'nif.jpg',
      );
    }
    if (docIdBytes != null && docIdBytes.isNotEmpty) {
      fields['doc_id'] = buildImageMultipart(
        bytes: docIdBytes,
        filename: docIdFilename ?? 'id.jpg',
      );
    }
    if (docShopBytes != null && docShopBytes.isNotEmpty) {
      fields['doc_shop'] = buildImageMultipart(
        bytes: docShopBytes,
        filename: docShopFilename ?? 'boutique.jpg',
      );
    }

    final form = FormData.fromMap(fields);
    final r = await _api.dio.post<Map<String, dynamic>>('/kyc/apply', data: form);
    return Map<String, dynamic>.from(r.data ?? {});
  }
}
