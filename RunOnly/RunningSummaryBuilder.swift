import Foundation

enum RunningSummaryBuilder {
    static func build(
        from runs: [RunningWorkout],
        vo2Max: VO2MaxSample?,
        restingHeartRateSnapshot: RestingHeartRateSnapshot?,
        now: Date = Date()
    ) -> RunningSummary {
        guard !runs.isEmpty else { return .empty }

        let calendar = Calendar.current
        let monthDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.distanceInKilometers }
        let yearDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .year) }
            .reduce(0) { $0 + $1.distanceInKilometers }

        return RunningSummary(
            monthDistanceKilometers: monthDistance,
            yearDistanceKilometers: yearDistance,
            monthDistanceText: formatDistance(monthDistance),
            yearDistanceText: formatDistance(yearDistance),
            recoveryReadiness: RecoveryReadinessCalculator.build(
                from: runs,
                restingHeartRateSnapshot: restingHeartRateSnapshot,
                now: now
            ),
            vo2MaxText: vo2Max.map { $0.value.formatted(.number.precision(.fractionLength(1))) } ?? "-",
            vo2MaxDateText: vo2Max.map { L10n.format("업데이트 %@", formatShortDate($0.date)) } ?? L10n.tr("VO2 Max 데이터 없음"),
            predicted5KText: predictTime(for: 5_000, from: runs, now: now),
            predicted10KText: predictTime(for: 10_000, from: runs, now: now),
            predictedHalfText: predictTime(for: 21_097.5, from: runs, now: now),
            predictedMarathonText: predictTime(for: 42_195, from: runs, now: now)
        )
    }

    private static func formatDistance(_ kilometers: Double) -> String {
        RunDisplayFormatter.distance(kilometers: kilometers, fractionLength: 1)
    }

    private static func formatShortDate(_ date: Date) -> String {
        RunDisplayFormatter.shortMonthDay(date)
    }

    private static func predictTime(for targetDistance: Double, from runs: [RunningWorkout], now: Date) -> String {
        guard let predictedSeconds = PredictionModel.predictedSeconds(
            for: targetDistance,
            from: runs,
            referenceDate: now
        ) else {
            return "-"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = predictedSeconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: predictedSeconds) ?? "-"
    }
}

enum RecoveryReadinessCalculator {
    static func build(
        from runs: [RunningWorkout],
        restingHeartRateSnapshot: RestingHeartRateSnapshot?,
        now: Date = Date()
    ) -> RecoveryReadiness {
        let calendar = Calendar.current
        let recent28Start = calendar.date(byAdding: .day, value: -28, to: now) ?? .distantPast
        let recent10Start = calendar.date(byAdding: .day, value: -10, to: now) ?? .distantPast
        let recent28Runs = runs.filter { $0.startDate >= recent28Start && $0.startDate <= now }
        let weeklyLoadChart = buildRecoveryLoadChart(from: recent28Runs, now: now)

        guard recent28Runs.count >= 3 else {
            return RecoveryReadiness(
                score: nil,
                status: L10n.tr("데이터 필요"),
                detail: L10n.tr("최근 러닝이 더 쌓이면 준비도를 계산합니다."),
                recommendationTitle: L10n.tr("러닝 데이터가 더 필요해요"),
                recommendationDetail: L10n.tr("최근 28일 안에 최소 3회의 러닝이 있으면 준비도를 보여드릴게요."),
                factors: [
                    L10n.format("최근 28일 러닝 %d/3회", recent28Runs.count),
                    L10n.tr("최소 3회가 쌓이면 준비도 계산 시작"),
                    L10n.tr("지금은 예측 대신 데이터 축적을 우선해요")
                ],
                confidenceText: L10n.tr("데이터가 더 쌓이면 계산"),
                recentLoadText: L10n.format("%d점", Int(weeklyLoadChart.reduce(0) { $0 + $1.load }.rounded())),
                lastRunText: runs.first.map { relativeTimeText(from: $0.startDate, to: now) } ?? "-",
                restingHeartRateText: restingHeartRateSnapshot.map { Self.restingHeartRateText(from: $0) },
                loadRatioText: nil,
                weeklyLoadChart: weeklyLoadChart,
                isDataSufficient: false,
                dataRequirementText: L10n.tr("최근 28일 안에 최소 3회의 러닝이 필요합니다.")
            )
        }

        guard recent28Runs.contains(where: { $0.startDate >= recent10Start }) else {
            return RecoveryReadiness(
                score: nil,
                status: L10n.tr("데이터 필요"),
                detail: L10n.tr("최근 10일 안의 러닝이 있어야 오늘 컨디션을 가늠할 수 있어요."),
                recommendationTitle: L10n.tr("최근 러닝이 더 필요해요"),
                recommendationDetail: L10n.tr("최근 10일 안에 러닝이 한 번 이상 쌓이면 준비도를 다시 계산할게요."),
                factors: [
                    L10n.tr("최근 28일 러닝 횟수는 충족"),
                    L10n.tr("최근 10일 안 러닝이 아직 없어요"),
                    L10n.tr("오늘은 점수보다 가볍게 다시 시작하는 쪽을 추천해요")
                ],
                confidenceText: L10n.tr("최근 러닝이 더 필요해요"),
                recentLoadText: L10n.format("%d점", Int(weeklyLoadChart.reduce(0) { $0 + $1.load }.rounded())),
                lastRunText: runs.first.map { relativeTimeText(from: $0.startDate, to: now) } ?? "-",
                restingHeartRateText: restingHeartRateSnapshot.map { Self.restingHeartRateText(from: $0) },
                loadRatioText: nil,
                weeklyLoadChart: weeklyLoadChart,
                isDataSufficient: false,
                dataRequirementText: L10n.tr("최근 10일 안에 러닝이 한 번 이상 필요합니다.")
            )
        }

        guard let lastRun = recent28Runs.max(by: { $0.startDate < $1.startDate }) else {
            return .empty
        }

        let baselinePace = median(
            recent28Runs.compactMap { paceSecondsPerKilometer(for: $0) }
        )
        let last7Start = calendar.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        let last3Start = calendar.date(byAdding: .day, value: -3, to: now) ?? .distantPast
        let total28Load = recent28Runs.reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let last7Load = recent28Runs
            .filter { $0.startDate >= last7Start }
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let last3Load = recent28Runs
            .filter { $0.startDate >= last3Start }
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }

        let baselineWeeklyLoad = max(total28Load / 4, 1)
        let baselineThreeDayLoad = max(total28Load * 3 / 28, 1)
        let loadRatio = last7Load / baselineWeeklyLoad
        let acuteRatio = last3Load / baselineThreeDayLoad
        let hoursSinceLastRun = max(now.timeIntervalSince(lastRun.startDate) / 3_600, 0)

        let acuteScore: Int
        switch acuteRatio {
        case ..<0.75: acuteScore = 34
        case ..<0.95: acuteScore = 38
        case ..<1.15: acuteScore = 32
        case ..<1.35: acuteScore = 22
        case ..<1.6: acuteScore = 12
        default: acuteScore = 4
        }

        let recoveryGapScore: Int
        switch hoursSinceLastRun {
        case 36...: recoveryGapScore = 30
        case 24..<36: recoveryGapScore = 24
        case 16..<24: recoveryGapScore = 18
        case 10..<16: recoveryGapScore = 12
        case 6..<10: recoveryGapScore = 6
        default: recoveryGapScore = 0
        }

        let weeklyBalanceScore: Int
        switch loadRatio {
        case 0.8...1.15: weeklyBalanceScore = 20
        case 0.65..<0.8, 1.15..<1.3: weeklyBalanceScore = 15
        case 0.5..<0.65, 1.3..<1.45: weeklyBalanceScore = 10
        default: weeklyBalanceScore = 5
        }

        let restingHeartRateScore: Int
        let restingHeartRateText: String?
        if let restingHeartRateSnapshot {
            let delta = restingHeartRateSnapshot.deltaFromBaseline
            restingHeartRateText = Self.restingHeartRateText(from: restingHeartRateSnapshot)
            switch delta {
            case ...1:
                restingHeartRateScore = 10
            case ...3:
                restingHeartRateScore = 7
            case ...5:
                restingHeartRateScore = 4
            default:
                restingHeartRateScore = 1
            }
        } else {
            restingHeartRateScore = 6
            restingHeartRateText = nil
        }

        var score = acuteScore + recoveryGapScore + weeklyBalanceScore + restingHeartRateScore

        if hoursSinceLastRun >= 72, loadRatio < 0.55 {
            score = min(score, 59)
        }

        score = max(0, min(score, 100))

        let status: String
        let detail: String
        let recommendationTitle: String
        let recommendationDetail: String

        switch score {
        case 82...:
            status = L10n.tr("좋음")
            detail = L10n.tr("최근 부하와 회복 간격이 안정적이에요.")
            recommendationTitle = L10n.tr("품질 훈련까지 무난해 보여요")
            recommendationDetail = L10n.tr("템포런이나 인터벌도 가능해 보이지만, 몸이 무겁다면 보통 러닝으로 낮춰도 좋아요.")
        case 63..<82:
            status = L10n.tr("보통")
            detail = L10n.tr("보통 러닝을 하기 좋은 흐름이에요.")
            recommendationTitle = L10n.tr("보통 러닝이나 지속주가 잘 맞아요")
            recommendationDetail = L10n.tr("오늘은 편하게 이어가는 지속주나 여유 있는 페이스의 러닝을 추천해요.")
        case 45..<63:
            status = L10n.tr("가볍게")
            detail = L10n.tr("최근 부하가 남아 있어 가볍게 가는 편이 좋아요.")
            recommendationTitle = L10n.tr("이지런 20~40분 정도가 잘 맞아요")
            recommendationDetail = L10n.tr("강한 자극보다는 몸을 푸는 느낌의 가벼운 러닝이 더 잘 어울려요.")
        default:
            status = L10n.tr("회복")
            detail = L10n.tr("최근 부하 대비 회복 여유가 적어 보여요.")
            recommendationTitle = L10n.tr("휴식이나 아주 가벼운 조깅이 좋아요")
            recommendationDetail = L10n.tr("오늘은 쉬거나 산책, 또는 아주 짧은 회복 조깅 정도로 마무리하는 편을 추천해요.")
        }

        let loadFactorText: String
        if loadRatio > 1.2 {
            loadFactorText = L10n.tr("최근 7일 부하가 평소보다 높은 편이에요")
        } else if loadRatio < 0.75 {
            loadFactorText = L10n.tr("최근 7일 부하는 평소보다 낮은 편이에요")
        } else {
            loadFactorText = L10n.tr("최근 7일 부하가 평소 범위 안에 있어요")
        }

        let recoveryFactorText: String
        switch hoursSinceLastRun {
        case 36...:
            recoveryFactorText = L10n.tr("마지막 러닝 뒤 충분히 쉬었어요")
        case 24..<36:
            recoveryFactorText = L10n.tr("마지막 러닝 뒤 회복 시간이 확보됐어요")
        case 12..<24:
            recoveryFactorText = L10n.tr("마지막 러닝이 아직 꽤 최근이에요")
        default:
            recoveryFactorText = L10n.tr("마지막 러닝이 매우 가까워요")
        }

        let heartRateFactorText: String
        if let restingHeartRateSnapshot {
            switch restingHeartRateSnapshot.deltaFromBaseline {
            case ...1:
                heartRateFactorText = L10n.tr("안정시 심박이 평소 범위예요")
            case ...3:
                heartRateFactorText = L10n.tr("안정시 심박이 조금 올라와 있어요")
            default:
                heartRateFactorText = L10n.tr("안정시 심박이 평소보다 높아요")
            }
        } else {
            heartRateFactorText = L10n.tr("안정시 심박 없이 러닝 기록 중심으로 계산했어요")
        }

        return RecoveryReadiness(
            score: score,
            status: status,
            detail: detail,
            recommendationTitle: recommendationTitle,
            recommendationDetail: recommendationDetail,
            factors: [loadFactorText, recoveryFactorText, heartRateFactorText],
            confidenceText: restingHeartRateSnapshot == nil
                ? L10n.tr("러닝 기록 기준")
                : L10n.tr("러닝 기록 + 안정시 심박 기준"),
            recentLoadText: L10n.format("%d점", Int(last7Load.rounded())),
            lastRunText: relativeTimeText(from: lastRun.startDate, to: now),
            restingHeartRateText: restingHeartRateText,
            loadRatioText: L10n.format("평소 대비 %.0f%%", loadRatio * 100),
            weeklyLoadChart: weeklyLoadChart,
            isDataSufficient: true,
            dataRequirementText: nil
        )
    }

    private static func buildRecoveryLoadChart(from runs: [RunningWorkout], now: Date) -> [RecoveryLoadPoint] {
        let calendar = Calendar.current
        let baselinePace = median(runs.compactMap { paceSecondsPerKilometer(for: $0) })

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: calendar.startOfDay(for: now)) else {
                return nil
            }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let dailyLoad = runs
                .filter { $0.startDate >= date && $0.startDate < nextDay }
                .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }

            return RecoveryLoadPoint(date: date, load: dailyLoad)
        }
    }

    private static func recoveryLoad(
        for run: RunningWorkout,
        baselinePaceSecondsPerKilometer: Double?
    ) -> Double {
        let minutes = max(run.duration / 60, 0)
        guard let baselinePaceSecondsPerKilometer,
              let runPace = paceSecondsPerKilometer(for: run),
              runPace > 0 else {
            return minutes
        }

        let intensityFactor = min(max(baselinePaceSecondsPerKilometer / runPace, 0.85), 1.2)
        return minutes * intensityFactor
    }

    private static func paceSecondsPerKilometer(for run: RunningWorkout) -> Double? {
        guard run.distanceInMeters >= 800, run.duration > 0 else {
            return nil
        }
        return run.duration / run.distanceInKilometers
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    private static func relativeTimeText(from date: Date, to now: Date) -> String {
        let elapsed = max(now.timeIntervalSince(date), 0)
        let hours = Int(elapsed / 3_600)

        if hours < 1 {
            return L10n.tr("1시간 이내")
        }
        if hours < 24 {
            return L10n.format("%d시간 전", hours)
        }

        return L10n.format("%d일 전", Int(elapsed / 86_400))
    }

    private static func restingHeartRateText(from snapshot: RestingHeartRateSnapshot) -> String {
        let delta = snapshot.deltaFromBaseline
        let signedDelta = delta >= 0 ? "+\(Int(delta.rounded()))" : "\(Int(delta.rounded()))"
        return L10n.format(
            "%d bpm (%@)",
            Int(snapshot.latestBPM.rounded()),
            signedDelta
        )
    }
}
