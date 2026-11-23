import Foundation

/// Texto del aviso al cerrar sesión con actividades pendientes de subir.
/// Lo pendiente queda en el dispositivo, pero no se sube hasta que el mismo usuario vuelva a entrar.
enum SignOutWarning {
    static func message(pendingCount: Int) -> String {
        let what = pendingCount == 1 ? "1 cambio sin subir" : "\(pendingCount) cambios sin subir"
        return "Tienes \(what). Se quedan guardados en este dispositivo y se suben cuando vuelvas a iniciar sesión con tu cuenta, pero no estarán en la nube ni en otros dispositivos hasta entonces."
    }
}
