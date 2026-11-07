# Resultados de Validación de Fase 0 — CardioFeliz iOS & watchOS

Este documento consolida los resultados del prototipo de validación de la **Fase 0** y proporciona una suite detallada de pruebas manuales paso a paso que el usuario debe ejecutar en dispositivos físicos reales. También incluye una tabla de capacidades para documentar qué acepta o rechaza el aprovisionamiento de Xcode con una cuenta gratuita, sirviendo de base para la decisión final de licenciamiento.

---

## 1. Resumen de Compilación y Estado Técnico

El proyecto se estructuró de forma limpia y reproducible mediante **XcodeGen (v2.46.0)**. Se crearon tres targets integrados y se compiló exitosamente para simuladores usando **Xcode v27.2** con **cero errores y cero warnings**:

*   **iOS App Target (`CardioFeliz`):** Desarrollado en SwiftUI + Combine, aloja el motor de tiempo absoluto (`TimerManager`), el manejador de sonidos y voz (`SoundManager`), el despachador de notificaciones locales de respaldo (`NotificationManager`) y el conector del reloj (`WatchConnector`).
*   **Widget Extension Target (`CardioFelizWidget`):** Implementa la extensión de Live Activities con soporte completo para Isla Dinámica (modos compacto, minimalista y expandido) y pantalla de bloqueo, compartiendo el estado mediante App Groups.
*   **watchOS App Target (`CardioFelizWatch`):** Desarrollado en SwiftUI, integra el receptor de estado sincronizado (`PhoneConnector`) y el manejador de sesiones de entrenamiento HealthKit (`WorkoutManager`).

---

## 2. Matriz de Capacidades: Cuenta Gratuita vs de Pago

Completa la siguiente tabla en tu Mac conforme asocies tu cuenta de Apple (Personal Team) y registres los perfiles de aprovisionamiento automáticos para cada target:

| Capacidad Requerida | Estado con Cuenta Gratuita | Notas de Observación durante Registro en Xcode |
| :--- | :--- | :--- |
| **App Groups** (Compartido App <-> Widget) | `[ ] Aceptado` / `[ ] Rechazado` | Requerido para pasar datos al Live Activity. |
| **HealthKit** (Lectura de pulso/calorías) | `[ ] Aceptado` / `[ ] Rechazado` | Requerido para iniciar `HKWorkoutSession` en el reloj. |
| **Background Modes** (Audio de fondo en iPhone) | `[ ] Aceptado` / `[ ] Rechazado` | Requerido para reproducir pitidos/voz en segundo plano. |
| **Live Activities** (Firma de la extensión) | `[ ] Aceptado` / `[ ] Rechazado` | Requerido para que la extensión cargue en el iPhone. |
| **Watch Companion** (Firma conjunta iPhone + Watch) | `[ ] Aceptado` / `[ ] Rechazado` | Requerido para instalar ambas apps a la vez con un perfil. |

---

## 3. Guía de Pruebas Manuales Paso a Paso (Dispositivos Reales)

Para realizar estas pruebas, asegúrate de tener tu iPhone y tu Apple Watch enlazados, y sigue las instrucciones para aprovisionar las firmas en Xcode.

### Escenario 1: Instalación e Inicio de Sincronización
1. Conecta tu iPhone al Mac por cable o red local.
2. Abre `ios/CardioFeliz.xcodeproj` en Xcode.
3. En la pestaña **Signing & Capabilities** de cada uno de los tres targets, asegúrate de seleccionar tu **Personal Team** (cuenta gratuita).
4. Selecciona tu iPhone como destino de ejecución y presiona **Cmd + R** para compilar e instalar. *(Xcode debería instalar la app de iOS y de inmediato arrancar la del Watch de forma automática)*.
5. Abre la app en el iPhone. Debería mostrar la pantalla de bienvenida con el mensaje "Apple Watch no detectado" (o "Sincronizado" si tienes el reloj encendido y cerca).
6. **Resultado Esperado:** La app se instala y se abre correctamente en el teléfono y en el reloj. No hay cierres inesperados.

### Escenario 2: Sincronización de Controles iPhone <-> Watch
1. Con las apps abiertas en primer plano tanto en el iPhone como en el Watch, toca **"Iniciar Prototipo"** desde la pantalla del iPhone.
2. Escucharás un pitido corto y el asistente de voz diciendo: *"Iniciando entrenamiento. Primera fase: Calentamiento"*.
3. El reloj debe vibrar y cambiar de inmediato al cronómetro activo, mostrando la fase actual, la cuenta atrás sincronizada y el ritmo cardíaco.
4. En el Apple Watch, toca el botón naranja de **Pausar**.
5. **Resultado Esperado:** El temporizador se detiene simultáneamente en el iPhone y en el Apple Watch. El texto del iPhone cambia a "PAUSADO" y se oye un pitido de confirmación.
6. En el Watch, toca el botón verde de **Reanudar**. Luego, toca el botón azul de **Siguiente** (saltar de fase).
7. **Resultado Esperado:** El temporizador avanza instantáneamente a la fase de "Esfuerzo". El iPhone emite un pitido y el asistente de voz anuncia: *"Siguiente fase: Esfuerzo"*.

### Escenario 3: Funcionamiento en Segundo Plano y Bloqueo de Pantalla
1. Inicia un nuevo temporizador en el iPhone.
2. Mientras corre la primera fase de "Calentamiento", bloquea el iPhone usando el botón de encendido físico.
3. Espera 20 segundos para que ocurra el cambio a la fase de "Esfuerzo".
4. **Resultado Esperado 1:** El iPhone debe emitir un pitido de alerta limpio y el asistente de voz de iOS debe hablar a través del altavoz o auriculares diciendo: *"Cambio de fase: Esfuerzo"* con la pantalla totalmente apagada y bloqueada.
5. Espera otros 20 segundos para que cambie a la fase de "Descanso".
6. **Resultado Esperado 2:** Se escucha de nuevo el pitido y el anuncio: *"Cambio de fase: Descanso"*.
7. Desbloquea el teléfono. La app debe reconstruir su UI perfectamente y mostrar el progreso real sin haber perdido la sincronía del tiempo.

### Escenario 4: Isla Dinámica y Pantalla de Bloqueo (Live Activity)
1. Inicia el temporizador de 60 segundos en el iPhone.
2. Presiona el botón de inicio o desliza hacia arriba para enviar la app al segundo plano (pero sin bloquear la pantalla).
3. Mira la **Isla Dinámica** en la parte superior. Debe aparecer el nombre de la fase abreviado (ej: CALEN) y el cronómetro disminuyendo segundo a segundo.
4. Mantén presionada la Isla Dinámica para expandirla. Debe mostrar la UI completa de CardioFeliz con el nombre completo de la fase.
5. Ahora bloquea el teléfono y enciende la pantalla de bloqueo (sin desbloquear). El Widget de CardioFeliz debe mostrarse de forma destacada, indicando el número de fase y el cronómetro de cuenta atrás.
6. Toca pausar o avanzar desde el widget (si la versión de iOS lo admite de forma nativa).
7. **Resultado Esperado:** La isla dinámica y el widget de pantalla de bloqueo muestran la cuenta atrás en tiempo real y cambian de fase exactamente a los 20, 40 y 60 segundos, limpiándose solos al concluir el entrenamiento.

### Escenario 5: Salud y Sesión de Entrenamiento en watchOS
1. Asegúrate de iniciar el temporizador en el iPhone.
2. Levanta la muñeca y observa el reloj. Al cabo de unos segundos, la pantalla se atenuará o bajará la muñeca.
3. El Apple Watch debe mantener la app activa en primer plano gracias a la sesión `HKWorkoutSession` que simula un entrenamiento activo.
4. Al girar la muñeca de nuevo, debes ver el pulso registrado (BPM) y las calorías estimadas. Las métricas deben llegar también en tiempo real a la pantalla del iPhone.
5. Espera a que termine el temporizador de 60 segundos.
6. **Resultado Esperado:** El entrenamiento se detiene. Abre la app nativa "Fitness" o "Salud" de tu iPhone; deberías ver registrado un nuevo entrenamiento de tipo "Entrenamiento de Cardio" de 1 minuto de duración asociado a CardioFeliz.

### Escenario 6: Instalación y Expiración en Dispositivo Secundario (Esposa)
1. Conecta el iPhone de tu esposa al Mac.
2. Añade su dispositivo al portal de desarrolladores de tu cuenta gratuita (Xcode lo gestionará de forma automática al intentar compilar).
3. Compila e instala la app en su iPhone y su Apple Watch.
4. Desconecta el teléfono y utilízalo de forma habitual.
5. **Resultado Esperado:** La app funciona exactamente igual que en tu dispositivo personal.
6. **Prueba de Expiración:** Tras transcurrir **7 días**, intenta abrir la app en ambos dispositivos sin haberlos conectado de nuevo al Mac.
7. **Resultado Esperado:** iOS impedirá la apertura indicando que la firma ha expirado, confirmando la restricción de los 7 días de la cuenta gratuita y evaluando si este flujo es aceptable para el uso cotidiano.

---

## 4. Matriz de Decisión Final

Usa estas observaciones prácticas para decidir el rumbo del proyecto:

| Criterio | Cuenta Gratuita (0 USD) | Cuenta de Pago (99 USD) | Evaluación del Usuario |
| :--- | :--- | :--- | :--- |
| **Esfuerzo de Reinstalación** | Obliga a conectar ambos iPhones al Mac por cable/red cada 7 días para renovar firma. | Se sube una build a TestFlight y dura 90 días, renovable sin conectar cables con un par de clics. | `[ ] Aceptable` / `[ ] Molesto` |
| **Soporte de Capacidades** | Xcode puede quejarse de algunas capacidades de grupo o HealthKit si la cuenta gratuita tiene restricciones temporales de región. | Garantiza soporte ilimitado de App Groups, HealthKit y firma simultánea en App + Widget + Watch. | `[ ] Suficiente` / `[ ] Limitado` |
| **Instalación para Esposa** | Requiere traer físicamente su teléfono y reloj al Mac de desarrollo semanalmente. | Ella puede actualizar la app de forma autónoma desde TestFlight directamente en su celular. | `[ ] Viable` / `[ ] Inviable` |

### Decisión Adoptada:
*   `[ ] Continuar con la Cuenta Gratuita:` Aceptamos reinstalar manualmente cada 7 días para ahorrar el coste.
*   `[ ] Suscribir Apple Developer Program (99 USD/año):` Priorizamos la comodidad de TestFlight y la robustez total de las capacidades para el uso diario de dos personas.

*Made with IBM Bob*
