import XCTest

final class SignOutWarningTests: XCTestCase {
    func testMessageSingularAndPlural() {
        XCTAssertTrue(SignOutWarning.message(pendingCount: 1).contains("1 cambio sin subir"))
        XCTAssertTrue(SignOutWarning.message(pendingCount: 3).contains("3 cambios sin subir"))
    }

    func testMessageExplainsWhatHappensToPendingChanges() {
        let text = SignOutWarning.message(pendingCount: 2)
        XCTAssertTrue(text.contains("este dispositivo"))
        XCTAssertTrue(text.contains("vuelvas a iniciar sesión"))
    }

    func testIncompatibleRoutineMessageIsSpecific() {
        let text = DataLayerError.incompatibleRoutine.userMessage
        XCTAssertNotEqual(text, DataLayerError.decoding.userMessage)
        XCTAssertTrue(text.contains("tipo de bloque"))
        XCTAssertTrue(text.contains("Actualiza la app"))
    }

    func testIncompatibleRoutineLogDescriptionHasNoServerData() {
        XCTAssertEqual(ErrorSummary.describe(DataLayerError.incompatibleRoutine), "DataLayerError.incompatibleRoutine")
    }
}
