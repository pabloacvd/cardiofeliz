# CardioFeliz iOS & watchOS

Aplicación nativa para iPhone, Apple Watch y Widget de pantalla de bloqueo / Dynamic Island de **CardioFeliz**, construida con SwiftUI, SwiftData, HealthKit, WatchConnectivity y ActivityKit.

---

## 🛠 Requisitos del Sistema
- **macOS:** Sonoma 14.5 o superior / Sequoia 15+.
- **Xcode:** Xcode 16.0 o superior (con SDKs de iOS 17+ y watchOS 10+).
- **XcodeGen:** Para generar el archivo `.xcodeproj` de forma declarativa (`brew install xcodegen`).
- **Dispositivos de destino:**
  - iPhone con iOS 17.0 o superior.
  - Apple Watch con watchOS 10.0 o superior (opcional para mediciones de pulso/calorías y control en muñeca).

---

## 🚀 Guía de Configuración Inicial

### 1. Clonar el repositorio
Asegúrate de estar en el directorio raíz o en la carpeta `ios/`:
```bash
cd ios
```

### 2. Configurar credenciales y firma (`Config.xcconfig`)
Copia la plantilla de configuración:
```bash
cp Config.xcconfig.template Config.xcconfig
```
Edita `Config.xcconfig` con tu editor preferido:
```xcconfig
// Tu Apple Team ID (10 caracteres, o déjalo vacío para firma personal automática)
DEVELOPMENT_TEAM =

// Prefijo único de Bundle Identifier
PRODUCT_BUNDLE_PREFIX = com.tuorganizacion.cardiofeliz

// URL y clave anónima pública de Supabase
SLASH = /
SUPABASE_URL = https:/$(SLASH)tu-proyecto.supabase.co
SUPABASE_ANON_KEY = tu_anon_key_aqui
```
*Nota: `Config.xcconfig` está en el `.gitignore` para proteger tus claves locales.*

### 3. Generar el proyecto Xcode
Ejecuta `xcodegen`:
```bash
xcodegen generate
```
Esto creará el archivo `CardioFeliz.xcodeproj` listo para abrir en Xcode.

---

## 🧪 Ejecución de Pruebas Unitarias

Para correr la suite completa de pruebas unitarias (más de 370 tests con paridad con Vitest):
```bash
xcodebuild test -scheme CardioFeliz -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CardioFelizTests
```

---

## 📱 Instalación en Dispositivos Físicos

### Instalación vía Xcode (Firma Personal Gratuita o Desarrollador)
1. Abre `CardioFeliz.xcodeproj` en Xcode:
   ```bash
   open CardioFeliz.xcodeproj
   ```
2. Conecta tu iPhone mediante cable USB o red Wi-Fi local.
3. En la barra superior de Xcode, selecciona tu iPhone como dispositivo de destino para el esquema `CardioFeliz`.
4. En los ajustes de Signing & Capabilities de los targets (`CardioFeliz`, `CardioFelizWidget`, `CardioFelizWatch`), selecciona tu cuenta de Apple ID personal o equipo de desarrollo.
5. Presiona **Cmd + R** para compilar e instalar en el iPhone y en el Apple Watch emparejado.
6. En tu iPhone, ve a **Ajustes > General > Gestión de VPN y dispositivos** y confía en el certificado de tu Apple ID.

---

## 🏗 Arquitectura y Estructura de Targets

- **`CardioFeliz` (iOS App):**
  - **Models / Engine:** Rutinas, validaciones, normalización, temporizadores (Tabata, EMOM, AMRAP, Triserie, Finisher, For Time), generador de audio nativo (`AVAudioEngine`), y Live Activity State Builder.
  - **Gamification:** XP, niveles, rachas, vacaciones, congeladores, misiones diarias, desafíos semanales, entrenador y analíticas con Swift Charts.
  - **Data Layer:** Local-first con SwiftData (`SwiftDataActivityCache`), sincronización bidireccional con Supabase (`ActivityStore`, `RoutineStore`, `VacationsStore`, `AchievementsStore`), y gestor de sesión (`SessionManager`).
  - **Views:** Vistas nativas SwiftUI fluidas con soporte Dark Mode y accesibilidad.
- **`CardioFelizWidget` (Widget & Live Activities):**
  - Live Activities en Isla Dinámica y Pantalla de Bloqueo con botones interactivos vía App Intents.
- **`CardioFelizWatch` (watchOS App):**
  - Sesión de entrenamiento activa con `HKWorkoutSession` / `HKLiveWorkoutBuilder`.
  - Medición en tiempo real de frecuencia cardíaca y calorías activas.
  - Hápticos sincronizados (`WKHapticType`) para cambios de fase y cuenta regresiva.
  - Comunicación bidireccional mediante `WatchConnectivity`.

---

## 📋 Documentación de Pruebas Manuales
- **General y escenarios integrales:** [`MANUAL-TESTS.md`](MANUAL-TESTS.md)
- **Segundo plano e Isla Dinámica:** [`BACKGROUND-MANUAL-TESTS.md`](BACKGROUND-MANUAL-TESTS.md)
- **Apple Watch y HealthKit:** [`WATCH-MANUAL-TESTS.md`](WATCH-MANUAL-TESTS.md)
