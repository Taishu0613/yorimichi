//
//  Municipality.swift
//  WAGhack
//

import SwiftData

@Model
final class Municipality {
    var code: String
    var prefectureName: String
    var municipalityName: String
    var prefectureKana: String
    var municipalityKana: String
    var isPrefecture: Bool
    var prefectureCode: String
    var historyTrivia: String
    var famousThingsTrivia: String
    /// みどころ(「この街でできること」)の一覧のJSON。順番が順位。中身は`YorimichiSpot.spots(fromJSON:)`で読む。
    /// 既定値はマイグレーションのため。既存の端末では、この列が空の行に次のマスタ同期で値が入る。
    var spotsJSON: String = ""

    init(
        code: String,
        prefectureName: String,
        municipalityName: String,
        prefectureKana: String,
        municipalityKana: String,
        isPrefecture: Bool,
        prefectureCode: String,
        historyTrivia: String,
        famousThingsTrivia: String,
        spotsJSON: String = ""
    ) {
        self.code = code
        self.prefectureName = prefectureName
        self.municipalityName = municipalityName
        self.prefectureKana = prefectureKana
        self.municipalityKana = municipalityKana
        self.isPrefecture = isPrefecture
        self.prefectureCode = prefectureCode
        self.historyTrivia = historyTrivia
        self.famousThingsTrivia = famousThingsTrivia
        self.spotsJSON = spotsJSON
    }

    @discardableResult
    func updateIfNeeded(from record: MunicipalityMasterRecord) -> Bool {
        guard prefectureName != record.prefectureName
                || municipalityName != record.municipalityName
                || prefectureKana != record.prefectureKana
                || municipalityKana != record.municipalityKana
                || isPrefecture != record.isPrefecture
                || prefectureCode != record.prefectureCode
                || historyTrivia != record.historyTrivia
                || famousThingsTrivia != record.famousThingsTrivia
                || spotsJSON != record.spotsJSON else {
            return false
        }

        prefectureName = record.prefectureName
        municipalityName = record.municipalityName
        prefectureKana = record.prefectureKana
        municipalityKana = record.municipalityKana
        isPrefecture = record.isPrefecture
        prefectureCode = record.prefectureCode
        historyTrivia = record.historyTrivia
        famousThingsTrivia = record.famousThingsTrivia
        spotsJSON = record.spotsJSON
        return true
    }
}
