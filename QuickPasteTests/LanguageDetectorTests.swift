import Testing
@testable import QuickPaste

// NaturalLanguageDetector is deterministic and on-device, so it can run in the
// suite directly. Samples are distinctive sentences to avoid close-language noise.
struct LanguageDetectorTests {
    let detector = NaturalLanguageDetector()

    @Test("Detects the dominant language of representative sentences", arguments: zip(
        [
            "The quick brown fox jumps over the lazy dog every morning.",
            "Le renard brun rapide saute par-dessus le chien paresseux.",
            "A rápida raposa marrom pulou sobre o cão preguiçoso à tarde.",
            "El rápido zorro marrón salta sobre el perro perezoso cada día.",
        ],
        [TranslationLanguage.english, .french, .portuguese, .spanish]
    ))
    func detectsLanguage(sample: String, expected: TranslationLanguage) {
        #expect(detector.detect(in: sample) == expected)
    }

    @Test("Abstains on empty or too-short input", arguments: ["", "hi", "  ok  "])
    func abstainsOnShortInput(sample: String) {
        #expect(detector.detect(in: sample) == nil)
    }

    @Test("Maps BCP-47 codes to supported targets by primary subtag")
    func mapsLanguageCodes() {
        #expect(TranslationLanguage(languageCode: "en") == .english)
        #expect(TranslationLanguage(languageCode: "pt-BR") == .portuguese)
        #expect(TranslationLanguage(languageCode: "zh-Hans") == .chinese)
        #expect(TranslationLanguage(languageCode: "qq") == nil)
    }
}
