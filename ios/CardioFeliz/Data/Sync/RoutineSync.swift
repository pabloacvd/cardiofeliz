import Foundation

// MARK: - Estado de caché y sincronización de rutina (espejo de `src/utils/routineSync.ts`)

enum PendingRoutineAction: String, Codable, Equatable, Sendable {
    case save
    case delete
}

struct RoutineCacheState: Codable, Equatable, Sendable {
    var customRoutine: RutinaData?
    var updatedAt: String?
    var pendingAction: PendingRoutineAction?

    init(
        customRoutine: RutinaData? = nil,
        updatedAt: String? = nil,
        pendingAction: PendingRoutineAction? = nil
    ) {
        self.customRoutine = customRoutine
        self.updatedAt = updatedAt
        self.pendingAction = pendingAction
    }

    static let initial = RoutineCacheState()
}

enum RoutineSyncLogic {
    /// Devuelve la rutina por defecto normalizada asignando el nombre de usuario provisto.
    static func getDefaultRoutine(
        displayName: String? = nil,
        provider: RoutineProvider = BundledRoutineProvider()
    ) -> RutinaData {
        let base = (try? provider.loadRoutine()) ?? RutinaData(
            usuario: "Usuario",
            edad: 30,
            objetivo: "Cardio",
            diasEntrenamiento: []
        )
        let normalized = RoutineNormalizer.normalizeRutina(base)
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return RutinaData(
            usuario: (name?.isEmpty ?? true) ? normalized.usuario : name!,
            edad: normalized.edad,
            objetivo: normalized.objetivo,
            diasEntrenamiento: normalized.diasEntrenamiento
        )
    }

    /// Parsea y valida el contenido de la caché local de rutina.
    static func parseAndValidateRoutineCache(_ raw: String?) -> RoutineCacheState {
        guard let raw, let data = raw.data(using: .utf8) else {
            return .initial
        }

        guard let decoded = try? JSONDecoder().decode(RoutineCacheState.self, from: data) else {
            return .initial
        }

        var customRoutine: RutinaData? = nil
        if let candidate = decoded.customRoutine {
            let validation = RoutineValidator.validateRutina(candidate)
            if validation.isValid {
                customRoutine = RoutineNormalizer.normalizeRutina(candidate)
            }
        }

        return RoutineCacheState(
            customRoutine: customRoutine,
            updatedAt: decoded.updatedAt,
            pendingAction: decoded.pendingAction
        )
    }

    /// Resuelve conflictos entre el estado local y los datos remotos de Supabase.
    /// Regla: Última escritura gana según `updated_at`. Si hay acción pendiente local, local manda.
    static func resolveRoutineConflict(
        local: RoutineCacheState,
        remote: RemoteRoutine?
    ) -> RoutineCacheState {
        // 1. Si hay acción pendiente local, local manda
        if local.pendingAction != nil {
            return local
        }

        // 2. Remoto no tiene rutina guardada (o fue borrada en otro dispositivo)
        guard let remote else {
            return RoutineCacheState(customRoutine: nil, updatedAt: nil, pendingAction: nil)
        }

        // 3. Validar datos remotos
        let validation = RoutineValidator.validateRutina(remote.data)
        guard validation.isValid else {
            return local
        }

        let normalizedRemote = RoutineNormalizer.normalizeRutina(remote.data)
        let remoteUpdatedIso = remote.updatedAt.map(SupabaseDate.format)

        // 4. Comparar fechas
        guard let localUpdatedStr = local.updatedAt, let localDate = SupabaseDate.parse(localUpdatedStr) else {
            // Local no tenía fecha registrada: remoto gana
            return RoutineCacheState(
                customRoutine: normalizedRemote,
                updatedAt: remoteUpdatedIso,
                pendingAction: nil
            )
        }

        guard let remoteDate = remote.updatedAt else {
            // Remoto no tiene fecha pero es válido y local sí tenía: si local no tiene cambios pendientes, aceptar remoto
            return RoutineCacheState(
                customRoutine: normalizedRemote,
                updatedAt: remoteUpdatedIso,
                pendingAction: nil
            )
        }

        if remoteDate >= localDate {
            // Remoto es más reciente o igual: remoto gana
            return RoutineCacheState(
                customRoutine: normalizedRemote,
                updatedAt: remoteUpdatedIso,
                pendingAction: nil
            )
        }

        // Local es más reciente
        return local
    }

    /// Devuelve la rutina efectiva a utilizar y si es personalizada.
    static func getEffectiveRoutine(
        cache: RoutineCacheState,
        displayName: String,
        provider: RoutineProvider = BundledRoutineProvider()
    ) -> (rutina: RutinaData, isCustom: Bool) {
        if let custom = cache.customRoutine {
            let effectiveUser = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? custom.usuario
                : displayName
            var r = custom
            r.usuario = effectiveUser
            return (rutina: r, isCustom: true)
        }

        return (rutina: getDefaultRoutine(displayName: displayName, provider: provider), isCustom: false)
    }
}
