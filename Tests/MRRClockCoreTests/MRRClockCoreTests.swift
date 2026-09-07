import Testing
@testable import MRRClockCore

@Test("the test target can import the core module")
func coreModuleImport() {
    #expect(MRRClockCore.metricsSpecVersion == 1)
}
