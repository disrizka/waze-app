part of '../../providers/sales_provider.dart';

enum StoreSelectStatus {
  selected, // sudah ada store aktif
  missing, // ada list store tapi belum dipilih
  emptyList, // daftar store kosong (belum fetch / memang tidak ada)
}
