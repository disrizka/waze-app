import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';

class EmployeeListScreen extends StatefulWidget {
  static const routeName = '/employee-list';

  const EmployeeListScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  // Primary color as requested
  static const primary = Color(0xFF4C6EF5);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hr = context.read<HrProvider>();
      hr.employeeList(context, refresh: true);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final hr = context.read<HrProvider>();
    // Infinite scroll trigger
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!hr.loadingMoreEmployees && hr.employeesHasMore) {
        hr.employeeList(context);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final hr = context.read<HrProvider>();
      hr.employeeList(context, refresh: true, search: value.trim());
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Employee List',
          style: TextStyle(
            color: Colors.black, // <-- AppBar title text is black
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSearchField(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: () => context.read<HrProvider>().employeeList(
                context,
                refresh: true,
                search: _searchController.text.trim(),
              ),
              child: Builder(
                builder: (_) {
                  if (hr.loadingEmployees && hr.employees.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!hr.loadingEmployees &&
                      hr.employees.isEmpty &&
                      (hr.employeesError == null ||
                          hr.employeesError!.isEmpty)) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount:
                        hr.employees.length +
                        (hr.loadingMoreEmployees || hr.employeesHasMore
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index >= hr.employees.length) {
                        // Last row = loading indicator or "no more"
                        if (!hr.employeesHasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'All employees loaded',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final e = hr.employees[index];
                      return _EmployeeTile(employee: e);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search name, email, or phone',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF5F7FF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No employees yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add employees or try changing your search keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeUser employee;
  static const primary = Color(0xFF4C6EF5);

  const _EmployeeTile({Key? key, required this.employee}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fullName = employee.fullName.isNotEmpty
        ? employee.fullName
        : (employee.email.isNotEmpty ? employee.email : 'No name');

    final subtitlePieces = <String>[
      if (employee.userRoleName.isNotEmpty) employee.userRoleName,
      if (employee.email.isNotEmpty) employee.email,
      if (employee.phone.isNotEmpty) employee.phone,
    ];
    final subtitle = subtitlePieces.join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0.4,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: _buildAvatar(),
          title: Text(
            fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          trailing: employee.isDeactivated
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EBFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    employee.userRoleName.isNotEmpty
                        ? employee.userRoleName
                        : 'Active',
                    style: const TextStyle(
                      fontSize: 11,
                      color: primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
          onTap: () {
            // TODO: navigate to employee detail screen when available
          },
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = employee.photoPath;
    final initials = _initialsFromName(
      employee.fullName.isNotEmpty
          ? employee.fullName
          : (employee.email.isNotEmpty ? employee.email : 'U'),
    );

    if (url.isEmpty) {
      return _initialAvatar(initials);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFE0E7FF),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: 44,
          height: 44,
          errorBuilder: (_, __, ___) => _initialAvatar(initials),
        ),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final two = parts.take(2).map((e) => e[0].toUpperCase()).join();
    return two.isNotEmpty ? two : 'U';
  }

  Widget _initialAvatar(String initials) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFE0E7FF),
      child: Text(
        initials,
        style: const TextStyle(color: primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}
