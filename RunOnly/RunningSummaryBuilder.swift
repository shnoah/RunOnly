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
    private enum RunnerLoadProfile {
        case beginner
        case tenK
        case halfReady
        case halfFull
    }

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
                effortBasisText: readinessEffortBasisText(from: recent28Runs),
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
                effortBasisText: readinessEffortBasisText(from: recent28Runs),
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
        let acuteLoadWindowHours = 84
        let acuteLoadWindowDays = Double(acuteLoadWindowHours) / 24
        let acuteLoadStart = calendar.date(byAdding: .hour, value: -acuteLoadWindowHours, to: now) ?? .distantPast
        let recent28Loads = recent28Runs.map { recoveryLoad(for: $0, baselinePaceSecondsPerKilometer: baselinePace) }
        let total28Load = recent28Loads.reduce(0, +)
        let last7Load = recent28Runs
            .filter { $0.startDate >= last7Start }
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let acuteLoadRuns = recent28Runs.filter { $0.startDate >= acuteLoadStart }
        let acuteLoad = acuteLoadRuns
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let acuteDistance = acuteLoadRuns.reduce(0) { $0 + $1.distanceInKilometers }

        let baselineWeeklyLoad = max(total28Load / 4, 1)
        let typicalSessionLoad = max(median(recent28Loads) ?? 0, 1)
        let lastRunLoad = recoveryLoad(for: lastRun, baselinePaceSecondsPerKilometer: baselinePace)
        let baselineAcuteLoad = max(total28Load * acuteLoadWindowDays / 28, typicalSessionLoad, 1)
        let loadRatio = last7Load / baselineWeeklyLoad
        let acuteRatio = acuteLoad / baselineAcuteLoad
        let lastRunLoadRatio = lastRunLoad / typicalSessionLoad
        let hoursSinceLastRun = max(now.timeIntervalSince(lastRun.startDate) / 3_600, 0)
        let priorRuns = recent28Runs.filter { $0.startDate < lastRun.startDate }
        let trainingProfileRuns = priorRuns.count >= 3 ? priorRuns : recent28Runs
        let runnerProfile = runnerLoadProfile(from: trainingProfileRuns)
        let profileDistances = trainingProfileRuns.map(\.distanceInKilometers).filter { $0 > 0 }
        let typicalDistance = max(median(profileDistances) ?? lastRun.distanceInKilometers, 0.1)
        let longestDistance = max(profileDistances.max() ?? typicalDistance, 0.1)
        let lastDistanceRatio = lastRun.distanceInKilometers / typicalDistance
        let longestDistanceRatio = lastRun.distanceInKilometers / longestDistance

        let acuteScore: Int
        switch acuteRatio {
        case ..<0.75: acuteScore = 26
        case ..<0.95: acuteScore = 24
        case ..<1.15: acuteScore = 18
        case ..<1.35: acuteScore = 12
        case ..<1.6: acuteScore = 6
        default: acuteScore = 2
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
            restingHeartRateScore = 8
            restingHeartRateText = nil
        }

        var score = acuteScore + recoveryGapScore + weeklyBalanceScore + restingHeartRateScore

        if shouldLiftSingleEasyRunScore(
            lastRun: lastRun,
            runnerProfile: runnerProfile,
            acuteLoadRuns: acuteLoadRuns,
            lastRunLoadRatio: lastRunLoadRatio,
            lastDistanceRatio: lastDistanceRatio,
            longestDistanceRatio: longestDistanceRatio,
            hoursSinceLastRun: hoursSinceLastRun,
            restingHeartRateScore: restingHeartRateScore
        ) {
            score = max(score, 63)
        } else if shouldHoldRecentHardThenEasyAtLight(lastRun: lastRun, acuteLoadRuns: acuteLoadRuns) {
            score = min(max(score, 45), 62)
        } else if shouldAvoidRecoveryForLowIntensityAccumulation(
            lastRun: lastRun,
            acuteLoadRuns: acuteLoadRuns,
            loadRatio: loadRatio
        ) {
            score = max(score, 45)
        }

        score = adjustedScoreForRecentHighLoad(
            score,
            lastRun: lastRun,
            lastRunLoadRatio: lastRunLoadRatio,
            hoursSinceLastRun: hoursSinceLastRun
        )
        score = adjustedScoreForRunnerProfile(
            score,
            runnerProfile: runnerProfile,
            lastRun: lastRun,
            lastRunLoadRatio: lastRunLoadRatio,
            lastDistanceRatio: lastDistanceRatio,
            longestDistanceRatio: longestDistanceRatio,
            acuteLoadRuns: acuteLoadRuns,
            acuteDistance: acuteDistance,
            typicalDistance: typicalDistance,
            hoursSinceLastRun: hoursSinceLastRun
        )
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

        let effortBasisText = readinessEffortBasisText(from: recent28Runs)
        let effortFactorText = effortFactorText(for: lastRun, lastRunLoadRatio: lastRunLoadRatio)

        return RecoveryReadiness(
            score: score,
            status: status,
            detail: detail,
            recommendationTitle: recommendationTitle,
            recommendationDetail: recommendationDetail,
            factors: [loadFactorText, recoveryFactorText, effortFactorText, heartRateFactorText],
            confidenceText: confidenceText(
                hasAppleEffort: recent28Runs.contains { $0.appleEffort != nil },
                hasRestingHeartRate: restingHeartRateSnapshot != nil
            ),
            recentLoadText: L10n.format("%d점", Int(last7Load.rounded())),
            lastRunText: relativeTimeText(from: lastRun.startDate, to: now),
            restingHeartRateText: restingHeartRateText,
            loadRatioText: L10n.format("평소 대비 %.0f%%", loadRatio * 100),
            effortBasisText: effortBasisText,
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
        guard minutes > 0 else { return 0 }

        if let appleEffort = run.appleEffort {
            return minutes * appleEffortLoadFactor(for: appleEffort.clampedScore)
        }

        guard let baselinePaceSecondsPerKilometer,
              let runPace = paceSecondsPerKilometer(for: run),
              runPace > 0 else {
            return minutes
        }

        let intensityFactor = min(max(baselinePaceSecondsPerKilometer / runPace, 0.80), 1.35)
        return minutes * intensityFactor
    }

    private static func appleEffortLoadFactor(for score: Double) -> Double {
        switch score {
        case ..<3:
            return 0.70
        case ..<5:
            return 0.90
        case ..<7:
            return 1.20
        case ..<8.5:
            return 1.70
        default:
            return 2.50
        }
    }

    private static func effortFactorText(for run: RunningWorkout, lastRunLoadRatio: Double) -> String {
        if let appleEffort = run.appleEffort {
            if appleEffort.clampedScore >= 7 {
                return L10n.tr("강도가 높아 짧아도 피로로 잡았어요")
            }
            if lastRunLoadRatio > 1.6 {
                return L10n.tr("마지막 러닝은 평소 1회보다 긴 부하였어요")
            }
            if lastRunLoadRatio <= 1.15 {
                return L10n.tr("마지막 러닝은 평소 1회 부하 범위예요")
            }
            return L10n.format("마지막 러닝 강도는 %@ %@ 기준이에요", appleEffort.sourceText, appleEffort.displayText)
        }

        return L10n.tr("Apple 노력 점수가 없어 시간과 페이스로 강도를 추정했어요")
    }

    private static func shouldLiftSingleEasyRunScore(
        lastRun: RunningWorkout,
        runnerProfile: RunnerLoadProfile,
        acuteLoadRuns: [RunningWorkout],
        lastRunLoadRatio: Double,
        lastDistanceRatio: Double,
        longestDistanceRatio: Double,
        hoursSinceLastRun: Double,
        restingHeartRateScore: Int
    ) -> Bool {
        guard isLowIntensityAppleEffort(lastRun),
              hoursSinceLastRun >= 24,
              acuteLoadRuns.count <= 1,
              lastRunLoadRatio <= 1.4,
              restingHeartRateScore >= 7 else {
            return false
        }

        switch runnerProfile {
        case .beginner:
            return lastDistanceRatio <= 1.15 && longestDistanceRatio <= 0.95
        case .tenK:
            return lastDistanceRatio <= 1.25 && longestDistanceRatio <= 1.0
        case .halfReady:
            return lastDistanceRatio <= 1.35 && longestDistanceRatio <= 1.05
        case .halfFull:
            return true
        }
    }

    private static func shouldAvoidRecoveryForLowIntensityAccumulation(
        lastRun: RunningWorkout,
        acuteLoadRuns: [RunningWorkout],
        loadRatio: Double
    ) -> Bool {
        guard isLowIntensityAppleEffort(lastRun), loadRatio <= 1.8 else { return false }
        return !acuteLoadRuns.contains { run in
            guard let appleEffort = run.appleEffort else { return false }
            return appleEffort.clampedScore >= 6
        }
    }

    private static func shouldHoldRecentHardThenEasyAtLight(
        lastRun: RunningWorkout,
        acuteLoadRuns: [RunningWorkout]
    ) -> Bool {
        guard isLowIntensityAppleEffort(lastRun) else { return false }
        return acuteLoadRuns.contains { run in
            guard let appleEffort = run.appleEffort else { return false }
            return appleEffort.clampedScore >= 7 && run.distanceInKilometers < 16
        }
    }

    private static func adjustedScoreForRecentHighLoad(
        _ score: Int,
        lastRun: RunningWorkout,
        lastRunLoadRatio: Double,
        hoursSinceLastRun: Double
    ) -> Int {
        guard hoursSinceLastRun < 36 else { return score }

        let distance = lastRun.distanceInKilometers
        let effortScore = lastRun.appleEffort?.clampedScore ?? 0
        let distanceEffortScore = lastRun.appleEffort?.clampedScore ?? 6
        let isRaceLike = effortScore >= 9.5
        let isHardLongRun = distance >= 20 && distanceEffortScore >= 6

        if (isRaceLike && distance >= 10) || isHardLongRun || lastRunLoadRatio >= 2.2 {
            return min(score, 44)
        }

        if effortScore >= 7 {
            return min(score, 62)
        }

        if distance >= 20 || lastRunLoadRatio >= 1.7 {
            return min(score, 62)
        }

        return score
    }

    private static func adjustedScoreForRunnerProfile(
        _ score: Int,
        runnerProfile: RunnerLoadProfile,
        lastRun: RunningWorkout,
        lastRunLoadRatio: Double,
        lastDistanceRatio: Double,
        longestDistanceRatio: Double,
        acuteLoadRuns: [RunningWorkout],
        acuteDistance: Double,
        typicalDistance: Double,
        hoursSinceLastRun: Double
    ) -> Int {
        guard hoursSinceLastRun < 36 else { return score }

        let distance = lastRun.distanceInKilometers
        let effortScore = lastRun.appleEffort?.clampedScore ?? 0
        let isRaceLike = effortScore >= 9.5

        switch runnerProfile {
        case .beginner:
            if isRaceLike, distance >= 5 {
                return min(score, 44)
            }
            if effortScore >= 8 || distance >= 8 || lastRunLoadRatio >= 1.5 || lastDistanceRatio >= 1.4 || longestDistanceRatio >= 1.05 {
                return min(score, 62)
            }
        case .tenK:
            if (isRaceLike && distance >= 10) || (distance >= 14 && effortScore >= 6) {
                return min(score, 44)
            }
            if distance >= 10 || lastRunLoadRatio >= 1.7 || lastDistanceRatio >= 1.25 || longestDistanceRatio >= 1.0 {
                return min(score, 62)
            }
        case .halfReady:
            if (isRaceLike && distance >= 10) || (distance >= 18 && effortScore >= 6) || lastRunLoadRatio >= 2.1 {
                return min(score, 44)
            }
            if acuteLoadRuns.count >= 2 && acuteDistance >= typicalDistance * 2.0 {
                return min(score, 62)
            }
            if distance >= 16 || lastRunLoadRatio >= 1.8 || lastDistanceRatio >= 1.6 || longestDistanceRatio >= 1.15 {
                return min(score, 62)
            }
        case .halfFull:
            if distance >= 16 && lastDistanceRatio >= 1.2 {
                return min(score, 62)
            }
        }

        return score
    }

    private static func isLowIntensityAppleEffort(_ run: RunningWorkout) -> Bool {
        guard let appleEffort = run.appleEffort else { return false }
        return appleEffort.clampedScore < 5
    }

    private static func runnerLoadProfile(from runs: [RunningWorkout]) -> RunnerLoadProfile {
        let distances = runs.map(\.distanceInKilometers).filter { $0 > 0 }
        guard !distances.isEmpty else { return .beginner }

        let averageWeeklyDistance = distances.reduce(0, +) / 4
        let longestDistance = distances.max() ?? 0

        if averageWeeklyDistance >= 35 || longestDistance >= 18 {
            return .halfFull
        }

        if (averageWeeklyDistance >= 25 && longestDistance >= 12) || (averageWeeklyDistance >= 20 && longestDistance >= 14) {
            return .halfReady
        }

        if averageWeeklyDistance >= 15 || longestDistance >= 7 {
            return .tenK
        }

        return .beginner
    }

    private static func readinessEffortBasisText(from runs: [RunningWorkout]) -> String? {
        let appleEffortCount = runs.filter { $0.appleEffort != nil }.count
        guard appleEffortCount > 0 else {
            return L10n.tr("PNR 추정")
        }
        return L10n.format("Apple 노력 %d회", appleEffortCount)
    }

    private static func confidenceText(hasAppleEffort: Bool, hasRestingHeartRate: Bool) -> String {
        switch (hasAppleEffort, hasRestingHeartRate) {
        case (true, true):
            return L10n.tr("Apple 노력 + 안정시 심박 기준")
        case (true, false):
            return L10n.tr("Apple 노력 기준")
        case (false, true):
            return L10n.tr("PNR 추정 + 안정시 심박 기준")
        case (false, false):
            return L10n.tr("PNR 추정 기준")
        }
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
