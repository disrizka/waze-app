import 'dart:io';

import 'package:flutter/material.dart';

class Employee {
  final String id;
  final String name;
  final String? phoneNumber;

  /// Jika mengambil dari internet
  final String? photoUrl;

  /// Jika memilih dari device (image_picker)
  final String? photoLocalPath;

  final bool online;
  final String checkInTime;

  ImageProvider get avatarProvider {
    if (photoLocalPath != null && photoLocalPath!.isNotEmpty) {
      return FileImage(File(photoLocalPath!));
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return NetworkImage(photoUrl!) as ImageProvider;
    }
    return const AssetImage('assets/placeholder.png'); // opsional
  }

  Employee({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.photoLocalPath,
    this.online = true,
    this.checkInTime = '11:00AM',
  });
}

class LeaveDay {
  final DateTime date;
  final int days;
  final String reason;
  final String status; // Approved / Pending / Rejected
  LeaveDay({
    required this.date,
    required this.days,
    required this.reason,
    this.status = 'Approved',
  });
}

class Reimbursement {
  final String title;
  final double amount;
  final DateTime date;
  final String status; // Paid / Pending / Rejected
  Reimbursement({
    required this.title,
    required this.amount,
    required this.date,
    this.status = 'Paid',
  });
}

class HrProvider extends ChangeNotifier {
  final List<Employee> _employees = [
    Employee(
      id: '2004882',
      name: 'Mirna Sari',
      photoUrl: 'https://i.pravatar.cc/150?img=47',
    ),
    Employee(
      id: '2004882',
      name: 'Sinthya',
      photoUrl: 'https://i.pravatar.cc/150?img=12',
    ),
    Employee(
      id: '2004882',
      name: 'Jamal',
      photoUrl: 'https://i.pravatar.cc/150?img=30',
    ),
    Employee(
      id: '2004882',
      name: 'Intan N',
      photoUrl: 'https://i.pravatar.cc/150?img=32',
    ),
    Employee(
      id: '2004882',
      name: 'Ursula',
      photoUrl: 'https://i.pravatar.cc/150?img=5',
    ),
    Employee(
      id: '2004882',
      name: 'Mita Khunaira',
      photoUrl: 'https://i.pravatar.cc/150?img=66',
    ),
  ];

  // Dummy data
  final Map<String, int> _leaveBalance = {
    'Mirna Sari': 6,
    'Sinthya': 8,
    'Jamal': 10,
    'Intan N': 12,
    'Ursula': 7,
    'Mita Khunaira': 9,
  };

  final Map<String, List<LeaveDay>> _leaveHistory = {};
  final Map<String, List<Reimbursement>> _reimbHistory = {};
  int totalLeaveAllowance(String employeeName) => 10;

  HrProvider() {
    // generate dummy history for each employee
    for (final e in _employees) {
      _leaveHistory[e.name] = [
        LeaveDay(
          date: DateTime.now().subtract(const Duration(days: 8)),
          days: 1,
          reason: 'Check up',
          status: 'Approved',
        ),
        LeaveDay(
          date: DateTime.now().subtract(const Duration(days: 28)),
          days: 2,
          reason: 'Family matters',
          status: 'Approved',
        ),
        LeaveDay(
          date: DateTime.now().subtract(const Duration(days: 45)),
          days: 1,
          reason: 'Personal errand',
          status: 'Pending',
        ),
      ];
      _reimbHistory[e.name] = [
        Reimbursement(
          title: 'Taxi meeting client',
          amount: 85_000,
          date: DateTime.now().subtract(const Duration(days: 3)),
          status: 'Pending',
        ),
        Reimbursement(
          title: 'Team lunch',
          amount: 240_000,
          date: DateTime.now().subtract(const Duration(days: 20)),
          status: 'Paid',
        ),
      ];
    }
  }

  List<Employee> get employees => List.unmodifiable(_employees);

  void addEmployee(Employee e) {
    _employees.add(e);
    notifyListeners();
  }

  void requestReimbursement({
    required String employeeName,
    required String title,
    required double amount,
    required String bank,
    required String accountNumber,
    String? attachmentName, // dummy
  }) {
    final list = _reimbHistory[employeeName] ??= [];
    list.add(
      Reimbursement(
        title: title,
        amount: amount,
        date: DateTime.now(),
        status: 'Pending',
      ),
    );

    // (dummy) langsung dianggap Paid agar tampilan "Accepted"
    list[list.length - 1] = Reimbursement(
      title: title,
      amount: amount,
      date: DateTime.now(),
      status: 'Paid',
    );

    notifyListeners();
  }

  void requestLeave({
    required String employeeName,
    required DateTime start,
    required DateTime end,
    required String reason,
    String? attachmentName,
  }) {
    // hitung jumlah hari inklusif
    final days = end.difference(start).inDays + 1;

    // kurangi balance (pastikan minimal 0)
    final current = _leaveBalance[employeeName] ?? 0;
    _leaveBalance[employeeName] = (current - days).clamp(0, 365);

    // masukkan ke history dengan status Pending -> Approved (dummy)
    final list = _leaveHistory[employeeName] ??= [];
    list.add(
      LeaveDay(date: start, days: days, reason: reason, status: 'Pending'),
    );

    // (opsional) langsung set Approved biar sama seperti desain
    list[list.length - 1] = LeaveDay(
      date: start,
      days: days,
      reason: reason,
      status: 'Approved',
    );

    notifyListeners();
  }

  Employee? getByName(String name) {
    try {
      return _employees.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  int usedLeaveAllowance(String employeeName) {
    final total = totalLeaveAllowance(employeeName);
    final remaining = leaveBalance(employeeName);
    final used = total - remaining;
    return used.clamp(0, total);
  }

  Employee? getByIndex(int index) {
    if (index < 0 || index >= _employees.length) return null;
    return _employees[index];
  }

  int leaveBalance(String employeeName) => _leaveBalance[employeeName] ?? 0;

  List<LeaveDay> leaveHistory(String employeeName) =>
      List.unmodifiable(_leaveHistory[employeeName] ?? const []);

  List<Reimbursement> reimbursementHistory(String employeeName) =>
      List.unmodifiable(_reimbHistory[employeeName] ?? const []);

  double reimbursementPendingTotal(String employeeName) {
    final list = _reimbHistory[employeeName] ?? const [];
    return list
        .where((r) => r.status == 'Pending')
        .fold(0.0, (sum, r) => sum + r.amount);
  }
}
