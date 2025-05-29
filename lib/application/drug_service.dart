import 'package:drug/domain/repositories/drug_repository.dart';
import 'package:drug/data/database/drug_database.dart';

class DrugService {
  final DrugRepository repo;

  DrugService(this.repo);

  Future<List<Drug>> getAllDrugs() => repo.getAllDrugs();
  Future<void> addDrug(Drug drug) => repo.insertDrug(drug);
  Future<void> addSchedule(DrugSchedule schedule) => repo.insertSchedule(schedule);
  Future<List<DrugSchedule>> getSchedules() => repo.getAllSchedules();
  Future<void> deleteSchedule(int id) => repo.deleteSchedule(id);
  Future<void> updateSchedule(DrugSchedule schedule) => repo.updateSchedule(schedule);
}