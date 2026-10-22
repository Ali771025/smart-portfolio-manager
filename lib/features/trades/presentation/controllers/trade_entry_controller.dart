import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/app_failure.dart';
import '../../data/trade_entry_repository.dart';
import '../../domain/models/trade_ticket.dart';

part 'trade_entry_controller.g.dart';

@Riverpod(keepAlive: true)
class TradeEntryController extends _$TradeEntryController {
  TradeEntryRepository get _repository => ref.read(tradeEntryRepositoryProvider);

  @override
  AsyncValue<Unit> build() {
    return const AsyncData(unit);
  }

  Future<Either<AppFailure, Unit>> submit(TradeTicket ticket) async {
    state = const AsyncLoading();
    final result = await _repository.submitTrade(ticket);
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (_) => state = const AsyncData(unit),
    );
    return result;
  }
}
