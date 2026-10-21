import Foundation

/// Nombres propios que el usuario ha usado hace poco, aprendidos del historial: así el reconocimiento
/// los espera y el modelo los escribe siempre igual, sin tener que añadirlos al diccionario.
public enum RecentNames {
    /// Palabras con mayúscula inicial que no son nombres (inglés: días, meses, el pronombre «I»).
    static let ignored: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
        "i", "i'm", "i'll", "i've", "i'd", "ok", "okay",
    ]

    /// Nombres que aparecen en al menos dos dictados recientes, los más repetidos primero.
    /// `known`: términos que ya están en el diccionario y no hace falta repetir.
    public static func extract(
        from history: [Dictation], now: Date = .now, window: TimeInterval = 24 * 3600, limit: Int = 12, excluding known: [String] = []
    ) -> [String] {
        let recent = history.prefix(60).filter { now.timeIntervalSince($0.date) < window }
        let knownWords = Set(known.flatMap { $0.lowercased().split(separator: " ").map(String.init) })
        // Por nombre: en cuántos dictados aparece, cuántas veces en total y el más reciente.
        var dictations: [String: Set<UUID>] = [:]
        var counts: [String: Int] = [:]
        var order: [String: Int] = [:]
        for (index, dictation) in recent.enumerated() {
            for name in names(in: dictation.text) where !knownWords.contains(name.lowercased()) {
                dictations[name, default: []].insert(dictation.id)
                counts[name, default: 0] += 1
                order[name] = min(order[name] ?? index, index)
            }
        }
        return dictations
            .filter { $0.value.count >= 2 }
            .keys
            .sorted { (counts[$0]!, -order[$0]!) > (counts[$1]!, -order[$1]!) }
            .prefix(limit)
            .map { $0 }
    }

    /// Palabras con mayúscula inicial que no empiezan frase: «Tavo» e «Inés» en «Yo siento que Tavo e Inés están bien».
    static func names(in text: String) -> [String] {
        var result: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            var sentenceStart = true
            for token in line.split(whereSeparator: \.isWhitespace) {
                let opensSentence = token.first.map { "¿¡«\"(".contains($0) } ?? false
                let word = token.trimmingCharacters(in: CharacterSet.letters.inverted)
                let closesSentence = token.last.map { ".!?:".contains($0) } ?? false
                defer { sentenceStart = closesSentence }
                guard !sentenceStart, !opensSentence, word.count >= 2, let first = word.first, first.isUppercase,
                      word.allSatisfy({ $0.isLetter || $0 == "'" }),
                      !ignored.contains(word.lowercased())
                else { continue }
                result.append(word)
            }
        }
        return result
    }
}
