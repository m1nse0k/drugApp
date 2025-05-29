import 'package:drug/data/database/drug_database.dart';
import 'package:drug/domain/repositories/drug_repository.dart';

class DrugRepositoryImpl implements DrugRepository {
  final db = DrugDatabase.instance;

  @override
  Future<List<Drug>> getAllDrugs() => db.getAllDrugs();

  @override
  Future<void> insertDrug(Drug drug) async => db.insertDrug(drug);

  @override
  Future<List<DrugSchedule>> getAllSchedules() => db.getAllSchedules();

  @override
  Future<void> insertSchedule(DrugSchedule schedule) async => db.insertSchedule(schedule);

  @override
  Future<void> deleteSchedule(int id) async => db.deleteSchedule(id);

  @override
  Future<void> updateSchedule(DrugSchedule schedule) async => db.updateSchedule(schedule);
}