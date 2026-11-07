# Pruebas manuales: Apple Watch (sub-tarea 6)

Requieren un iPhone real emparejado con un Apple Watch real (watchOS 10 o superior). El simulador no sirve para esto: no mide pulso ni calorías, y el emparejamiento de `WatchConnectivity` entre simuladores es poco fiable. Instala la app del iPhone (incluye la del Watch) y ábrela una vez en cada dispositivo.

Usa un bloque corto (un Tabata o un EMOM de 3 min). Comprueba antes, en el iPhone, que hay peso guardado en el perfil: sin peso no hay estimación por MET con la que comparar.

Para el escenario 11 hace falta un bloque con fases manuales (Triserie o Finisher); para el 12, un FOR_TIME.

| # | Escenario | Resultado esperado | OK |
|---|-----------|--------------------|----|
| 1 | Iniciar un bloque en el iPhone con el Watch en la muñeca y bajar el brazo | El Watch pide permiso de Salud la primera vez; la app del Watch sigue activa con la muñeca baja y el contador no se detiene | [ ] |
| 2 | Aceptar el permiso de Salud | Solo se piden: leer frecuencia cardíaca y energía activa, y escribir entrenamientos. Nada de registros clínicos | [ ] |
| 3 | Ver el Watch durante el bloque | Muestra la fase (con el color de su tipo), el ejercicio, el tiempo restante, pulso y kcal | [ ] |
| 4 | Cambio de fase | El Watch vibra: distinto en trabajo, descanso y calentamiento | [ ] |
| 5 | Últimos 3 segundos de una fase | Un toque suave por segundo (3, 2, 1); no hay toques en pausa | [ ] |
| 6 | Abrir la app del Watch a mitad de un bloque ya iniciado | Muestra la fase y el tiempo correctos de inmediato, sin vibrar al entrar | [ ] |
| 7 | Pausar desde el Watch | El iPhone se pausa, su contador se congela y el Watch muestra «PAUSADO» | [ ] |
| 8 | Reanudar desde el Watch | El iPhone reanuda con el tiempo restante correcto; ambos coinciden | [ ] |
| 9 | «Siguiente» desde el Watch | El iPhone pasa de fase y suena su tono | [ ] |
| 10 | Pausar y reanudar desde el iPhone | El Watch lo refleja; el pulso sigue registrándose al reanudar | [ ] |
| 11 | Fase manual (Triserie/Finisher) | El Watch muestra el tiempo transcurrido; el botón es «Listo» y avanza la fase | [ ] |
| 12 | FOR_TIME | El Watch cuenta hacia arriba | [ ] |
| 13 | «Terminar» desde el Watch | El bloque termina en el iPhone y aparece el modal de fin | [ ] |
| 14 | Terminar el bloque en el iPhone | El Watch vibra una vez («éxito») y vuelve a la pantalla de reposo | [ ] |
| 15 | Abrir la app Salud del iPhone tras el bloque | Aparece un entrenamiento «Cardio mixto» con la duración, el pulso y las calorías | [ ] |
| 16 | Modal de fin de bloque en el iPhone | Muestra pulso medio y kcal del Watch cuando llega el resumen (puede tardar unos segundos) | [ ] |
| 17 | Terminar todos los bloques de un día con Watch | La actividad del día guarda como `calories_kcal` la suma de las kcal medidas; es menor que la estimación por MET (esperable: la energía activa no incluye el reposo) | [ ] |
| 18 | Un día con algunos bloques hechos sin el Watch | `calories_kcal` = kcal medidas de los bloques con Watch + estimación por MET de los demás | [ ] |
| 19 | Un día entero sin Watch | `calories_kcal` conserva la estimación por MET de siempre | [ ] |
| 20 | Alejar el iPhone fuera de alcance (modo avión en el iPhone) durante un bloque | El Watch sigue contando por las fechas y muestra «iPhone fuera de alcance» | [ ] |
| 21 | Con el iPhone fuera de alcance, pulsar Pausar en el Watch | Vibración de error y «No se pudo enviar»; el iPhone no se pausa después al volver a estar en alcance | [ ] |
| 22 | Terminar el bloque con el iPhone fuera de alcance y recuperarlo después | El Watch cierra su sesión sola cuando pasa el fin planificado y su resumen llega al iPhone al volver | [ ] |
| 23 | Cerrar la app del iPhone a la fuerza durante un bloque con el Watch | El Watch no se queda con una sesión de Salud abierta: la cierra al caducar el estado (fin planificado + 10 s) | [ ] |
| 24 | Abrir la app del Watch sin entrenamiento en curso | Dice «Inicia el entrenamiento en el iPhone»; no hay botón de iniciar ni sesión de Salud abierta (el icono de entrenamiento no aparece en la esfera) | [ ] |
| 25 | Denegar el permiso de escritura de entrenamientos en Salud y empezar un bloque | El Watch avisa «Sin permiso de Salud…»; cronómetro, hápticos y comandos funcionan; no hay pulso ni entrenamiento guardado | [ ] |
| 26 | Dos bloques seguidos del mismo día | Cada bloque crea su propio entrenamiento en Salud; no se mezclan ni se cuelga una sesión del bloque anterior | [ ] |
| 27 | Pulsar «Terminar» en el Watch justo al final de la fase | No se produce doble fin ni dos entrenamientos en Salud | [ ] |
| 28 | Batería del Watch: un bloque de 15 min | Anota el consumo; una sesión de entrenamiento activa gasta más que el uso normal | [ ] |

Anota cualquier fallo con el escenario, el modelo de iPhone y de Watch, y las versiones de iOS y watchOS.

Cosas que conviene mirar aunque no sean un escenario:

- Si en el escenario 1 el Watch se suspende con la muñeca baja, la causa más probable es que el modo de fondo `workout-processing` no se esté aplicando; revisa `WKBackgroundModes` en `CardioFelizWatch/Info.plist`.
- Con una cuenta gratuita de desarrollador puede que el entitlement de HealthKit no se firme. Si el permiso nunca aparece, comprueba la firma del target `CardioFelizWatch`.
- El mapeo de vibraciones (`WorkoutManager.play`) se eligió sin poder sentirlo. Si alguna se confunde con otra, ajusta ahí el `WKHapticType`.
