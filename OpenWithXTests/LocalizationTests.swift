import Testing
@testable import OpenWithX

struct LocalizationTests {
    @Test func onlySimplifiedChineseUsesChineseAndOtherLanguagesFallBackToEnglish() {
        for language in ["zh-Hans", "zh-Hans-CN", "zh-CN", "zh-SG"] {
            #expect(AppText.text("Open in VS Code", "使用 VS Code 打开", languages: [language]) == "使用 VS Code 打开")
        }
        for languages in [["en-US"], ["fr-FR", "zh-Hans"], ["zh-Hant-TW"], ["ja-JP"], []] {
            #expect(AppText.text("Open in VS Code", "使用 VS Code 打开", languages: languages) == "Open in VS Code")
        }
    }
    @Test func failureGuidanceUsesChineseOrEnglishFallback() {
        let failure = OpenFailure(error: VSCodeSelection.Failure.reselect)
        #expect(failure.message(languages: ["zh-CN"]) == "所选 VS Code 副本或授权已失效。")
        #expect(failure.message(languages: ["en"]) == "The selected VS Code copy or its authorization is no longer valid.")
        #expect(failure.recovery(languages: ["fr", "zh-Hans"]) == "Select the stable version of VS Code again. Another copy will not be substituted automatically.")
    }

}
