//
//  GlobalStats+AccountStats.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.07.26.
//

import Foundation

extension GlobalStats {
    init(from accountStats: AccountStats) {
        let correct = accountStats.correctAnswers ?? 0
        let wrong = accountStats.falseAnswers ?? 0
        self.init(
            totalAnswers: accountStats.totalAnswers ?? (correct + wrong),
            correctAnswers: correct,
            falseAnswers: wrong,
            quizzesPlayed: accountStats.quizzesPlayed ?? 0,
            playTime: accountStats.playTime ?? 0,
            currentStreak: accountStats.currentStreak ?? 0,
            bestStreak: accountStats.bestStreak ?? 0
        )
    }
}
