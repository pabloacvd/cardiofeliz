import Foundation

/// URL y clave anónima de Supabase leídas de `Info.plist` (que a su vez las toma de
/// `Config.xcconfig`, ignorado por git). Misma validación que `isValidConfig` de `src/lib/supabase.ts`:
/// HTTPS obligatorio (http solo para localhost) y clave de más de 20 caracteres.
/// Si algo falta o no es válido, `fromBundle` devuelve nil y la app muestra "sin configurar".
struct SupabaseConfig: Equatable, CustomStringConvertible {
    let url: URL
    let anonKey: String

    init?(urlString: String?, anonKey: String?) {
        guard let rawURL = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !rawURL.isEmpty,
              let rawKey = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines), !rawKey.isEmpty
        else { return nil }

        // Una variable de build sin resolver llega como "$(NOMBRE)"; los valores del .example son marcadores.
        guard !rawURL.hasPrefix("$("), !rawKey.hasPrefix("$(") else { return nil }
        guard !rawURL.lowercased().contains("tu-proyecto"), rawKey != "tu_clave_anon_publica" else { return nil }

        guard let url = URL(string: rawURL), let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil
        else { return nil }
        let isLocalhost = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocalhost) else { return nil }
        guard rawKey.count > 20 else { return nil }

        self.url = url
        self.anonKey = rawKey
    }

    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig? {
        SupabaseConfig(
            urlString: bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            anonKey: bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        )
    }

    /// Nunca imprime la clave.
    var description: String { "SupabaseConfig(host: \(url.host ?? "?"), anonKey: <redacted>)" }
}
