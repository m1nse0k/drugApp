import 'package:drug/data/database/drug_database.dart';

abstract class DrugRepository {
  Future<List<Drug>> getAllDrugs();
  Future<void> insertDrug(Drug drug);
  Future<List<DrugSchedule>> getAllSchedules();
  Future<void> insertSchedule(DrugSchedule schedule);
  Future<void> deleteSchedule(int id); // 추가
  Future<void> updateSchedule(DrugSchedule schedule); // 추가
}
