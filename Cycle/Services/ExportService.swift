import Foundation
import UniformTypeIdentifiers

enum ExportService {
    static func makeJSONURL(from snapshot: HealthExportSnapshot) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "cycle-export-\(filenameStamp()).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func makeCSVURL(from snapshot: HealthExportSnapshot) throws -> URL {
        var lines: [String] = []
        lines.append("type,id,date,value,extra")

        for cycle in snapshot.cycles {
            lines.append("cycle,\(cycle.id.uuidString),\(iso(cycle.startDate)),start,\(cycle.source)")
            if let end = cycle.endDate {
                lines.append("cycle,\(cycle.id.uuidString),\(iso(end)),end,")
            }
        }
        for flow in snapshot.flowEntries {
            lines.append("flow,\(flow.id.uuidString),\(iso(flow.date)),\(flow.intensity),spotting=\(flow.spotting)")
        }
        for checkIn in snapshot.checkIns {
            let mood = checkIn.mood.map(String.init) ?? ""
            let energy = checkIn.energy.map(String.init) ?? ""
            let sleep = checkIn.sleepQuality.map(String.init) ?? ""
            let symptoms = checkIn.symptoms.map { "\($0.type):\($0.intensity)" }.joined(separator: "|")
            let note = (checkIn.note ?? "").replacingOccurrences(of: ",", with: ";")
            lines.append("checkin,\(checkIn.id.uuidString),\(iso(checkIn.date)),mood=\(mood);energy=\(energy);sleep=\(sleep),\(symptoms);\(note)")
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "cycle-export-\(filenameStamp()).csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func filenameStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
