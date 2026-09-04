# Diseño: el viaje del bolsillo, y los viajes que no te representan

**Fecha:** 2026-09-04
**Estado:** aprobado en conversación, pendiente de plan de implementación
**Audiencia:** el autor y el agente de codificación

---

## 0. Por qué existe este documento

Dos problemas distintos que comparten un mismo punto de encuentro, la hoja de
resumen al terminar un viaje:

1. **El estimador de autonomía no distingue contexto.** Un día manejando
   despacio a propósito, para cuidar la carga, mueve la cifra aprendida como si
   fuera tu forma normal de manejar. No hay forma de decirle que ese viaje no te
   representa, salvo borrarlo entero.
2. **El viaje automático no habla.** Se graba y se aprende con la pantalla
   apagada, pero no avisa nada, el resumen se descarta, y probablemente el GPS
   ni despierta. O sea: no hay dónde poner la pregunta del punto 1.

El punto 2 es prerrequisito del punto 1.

---

## 1. Estado actual, verificado en el código

### 1.1 Cómo se estima la autonomía hoy

**Energía disponible** (`RangeEstimator.usableWh`, `range_estimator.dart:135`):

```
bruto    = remainingCapacityAh (contador del BMS) x voltaje del pack
fracción = (Vmin - corte) / (Vpromedio - corte), techo 1.0
usable   = bruto x fracción
```

El corte sale del ajuste de subvoltaje del propio BMS (`cellUvp`) cuando llegó
el frame de ajustes y es creíble (entre 1.5 V y 3.6 V); si no, 3.0 V.

**Consumo aprendido** (`RangeEstimator.addSegment`, `range_estimator.dart:101`):

Cada viaje guardado aporta una muestra, `(energyOut - energyIn) / distanceKm`.

- `energyOut` prefiere el contador culombimétrico: (Ah inicial menos Ah final)
  por voltaje medio del viaje. Solo cae a integrar potencia si no hay contador.
- `energyInWh` siempre es integrado: el contador da un neto y no separa
  direcciones.
- La distancia son pasos great-circle entre fixes, y solo cuentan con paso de
  1.5 m o más y velocidad de 1.5 km/h o más.
- Se descarta la muestra con menos de 0.2 km, energía neta no positiva, o
  Wh/km fuera de [2, 400].
- Lo que sobrevive entra en una media exponencial pesada por distancia, con
  vida media de 40 km.

**Los dos números** (`RangeOutlook.from`, `range_outlook.dart:66`):

```
ahora      = usable / whPerKm
pack lleno = capacidad x (3.7 V x celdas) x fracción / whPerKm
```

La capacidad medida gana sobre la del catálogo. El lleno no es el ahora escalado
por porcentaje, a propósito.

**La banda** sale solo de los km acumulados: menos de 5 km da 30%, menos de
50 km da 18%, de 50 en adelante 10%.

**Nada más entra.** Velocidad media, pendiente, temperatura, tiempo parado y
pasajero se graban en cada viaje y ninguno llega al estimador.

### 1.2 Los cuatro defectos del viaje automático

Verificados sobre `main` en 9ed439b.

| # | Defecto | Evidencia |
|---|---------|-----------|
| 1 | El GPS probablemente no despierta con la pantalla apagada, así que el viaje nunca arranca | No hay `ACCESS_BACKGROUND_LOCATION` en el manifest, y el armado previo del GPS corre con el reclamo `link`, que inicia el servicio sin tipo location (`bms_service.dart:1314` pasa `usesRealLocation` solo si el reclamo es `trip`) |
| 2 | Nada escucha `autoTripEvents` | Cero oyentes en `lib` y en `test`. `autoTripStarted` y `autoTripStopped` están traducidos a los dos idiomas y nunca se muestran |
| 3 | El resumen se descarta en un cierre automático | La hoja la abre `_stop()` en `trip_screen.dart:93`, solo al apretar el botón. `_updateAutoTrip` llama a `stopTrip()` y tira el `TripOutcome` |
| 4 | La notificación de un viaje automático dice "Trip", en inglés, con cuerpo vacío | `notificationTitle` arranca con el literal `'Trip'` (`bms_service.dart:1178`) y `notificationText` queda en null hasta que `trip_screen` se abre y los asigna |

Lo que sí funciona hoy, y no hay que tocar: el viaje es el mismo objeto que ve
la UI, se guarda en la base, y `relearnRangeFromTrips` corre dentro de
`stopTrip`, así que el aprendizaje ocurre con la pantalla apagada. El enlace
sobrevive porque `linkWatch` viene encendido y toma el servicio, y la energía
sale del contador culombimétrico, que sigue contando en los cortes de BLE.

---

## 2. Decisiones tomadas

| Decisión | Valor | Por qué |
|----------|-------|---------|
| Enfoque | Preguntar, no adivinar | La detección automática silenciosa cambia el número sin que el usuario sepa por qué, que es la incomodidad que originó todo esto |
| Umbral | El viaje movería la cifra aprendida más de **5%** | Atado a la consecuencia, no al desvío: un viaje raro de 2 km no puede mover nada y no debe preguntar |
| Dirección | Los dos lados, alto y bajo | Un día con pasajero o viento en contra tampoco te representa |
| Sin respuesta | Cuenta como normal | Quien ignore la pregunta se queda exactamente con el comportamiento de hoy |
| Peso de una excepción | Cero, queda fuera | YAGNI: un peso parcial es un botón más y una explicación más |

### 2.1 Qué significa el 5% en la práctica

Con 17.5 Wh/km aprendidos y 100 km de peso acumulado, el desplazamiento de la
cifra por una muestra nueva es:

```
desplazamiento = km x (muestra - promedio) / (peso x 0.5^(km/40) + km)
```

Para que llegue al 5% de 17.5 Wh/km, o sea 0.875:

| Distancia del viaje | Tiene que salir fuera de lo tuyo |
|---|---|
| 10 km | 47% |
| 20 km | 23% |
| 40 km | 11% |

O sea: pregunta poco, y solo cuando de verdad importa. El umbral va como una
constante con nombre, al lado de las de `VerdictThresholds`, para que
recalibrarlo sea una línea.

### 2.2 Límites conocidos, aceptados

- **Marca viajes enteros.** El caso de "manejé lento solo el último tramo" es
  medio viaje y no se resuelve. El promedio del viaje mixto sigue siendo
  parecido a la mezcla real.
- **No normaliza por contexto.** Pendiente, velocidad y temperatura siguen sin
  entrar al cálculo. Esto no hace el algoritmo más inteligente, hace que un
  viaje no representativo no lo contamine. Normalizar por contexto es otro
  trabajo, y se decide después de ver si el residuo molesta.
- **No hay decaimiento por tiempo.** Lo aprendido en invierno pesa al 100%
  hasta que se rueden 40 km nuevos. Fuera de alcance, anotado.
- **El número en vivo tiende optimista.** Durante el viaje el camino en vivo
  integra potencia de las lecturas recibidas y el enlace se cae mucho, así que
  pierde Wh mientras el GPS sigue sumando km. Se corrige solo al parar, cuando
  entra el contador culombimétrico. Fuera de alcance, anotado.

---

## 3. Pieza A: que el viaje del bolsillo funcione y hable

Sin esto la pregunta de la pieza B no tiene dónde aparecer, porque el caso
normal es que nadie esté mirando cuando el viaje termina.

### A1. GPS con la pantalla apagada

- Dar el tipo location al servicio también cuando el detector de auto arranque
  necesita un fix, no solo cuando ya hay un viaje abierto.
- Agregar `ACCESS_BACKGROUND_LOCATION` al manifest y pedirlo cuando haga falta.
- **VERIFICAR en el teléfono real.** Depende de la versión de Android y del
  fabricante, y ningún test responde esto.
- **Plan si Android no lo concede:** la app lo dice claro y ofrece el viaje
  manual como alternativa, en lugar de aprender nada en silencio. Ver A5.

### A2. Escuchar los eventos a nivel de app

Mover el oyente de `autoTripEvents` de "ninguna pantalla" a nivel de app, para
que un arranque y un cierre se anuncien sin importar qué pantalla esté abierta,
o ninguna.

### A3. Guardar el resumen de un cierre automático

El `TripOutcome` de un viaje cerrado solo se guarda como pendiente, y la hoja de
resumen aparece la próxima vez que se abre la app. Es la misma hoja de hoy, no
una nueva.

### A4. El texto de la notificación deja de vivir en la pantalla

Sacar `notificationTitle` y `notificationText` de `trip_screen` a un lugar que la
app fije siempre al arrancar, para que un viaje automático tenga título correcto
y en el idioma del usuario.

### A5. Decir cuando no se pudo grabar

Cuando el auto arranque no puede abrir un viaje por falta de ubicación o de
permiso en segundo plano, decirlo donde se vea: en la notificación y en la app.
Hoy el problema se guarda en `lastLocationProblem` y ahí muere.

---

## 4. Pieza B: la pregunta de representatividad

### 4.1 La marca es un estado del viaje, no un diálogo

Tres estados: **sin responder**, **normal**, **excepción**. Columna nueva en la
tabla de viajes.

`tripsForLearning` (`repository.dart:354`) filtra las excepciones. La
reconstrucción desde cero que ya existe hace el resto sola, igual que hoy al
borrar un viaje. Eso da dos cosas gratis: cambiar la respuesta después recalcula
todo, y la respuesta es reversible.

### 4.2 Dónde aparece

Como es un estado y no un diálogo, aparece donde sea que se vea el viaje:

- En la hoja de resumen, si estás ahí cuando termina.
- En la fila del viaje en el historial, si no estabas.
- Como aviso al abrir la app, si quedó pendiente **y** movió el número más
  del 5%.

Un toque para responder. Si nunca se responde, cuenta como normal.

### 4.3 La letra

La pregunta dice qué midió, cuánto se aparta, y qué le hace al número. Tres
datos, una frase de consecuencia:

> **¿Este viaje te representa?**
> Salió en 24 Wh/km, un 32% por encima de lo tuyo. Si lo tomo como normal, tu
> autonomía baja de 48 a 43 km.
>
> [ Es normal ]  [ Fue una excepción ]

Al responder, confirmación inmediata de la consecuencia, no un "guardado":

> Listo. Tu autonomía queda en 48 km.

### 4.4 Feedback durante y después del viaje

- **Durante:** la notificación del servicio dice "Grabando viaje" con el cuerpo
  que ya existe (velocidad, distancia, SOC, Wh/km). Eso es el anuncio del
  arranque automático; no se agrega una notificación aparte.
- **Al cerrarse solo:** la misma notificación, que pasa a manos del reclamo
  `link` porque seguís conectado, dice "Viaje guardado, 23.4 km, 18 Wh/km" por
  unos minutos y después vuelve al texto normal de conectado. Cero dependencias
  nuevas, cero permisos nuevos, y usa el árbitro de un solo espacio que ya
  existe.

---

## 5. Pruebas

### 5.1 Unitarias

| Qué | Dónde |
|---|---|
| El desplazamiento supera o no el 5%, por distancia y desvío | nuevo, junto a `range_weighting_test.dart` |
| Una excepción queda fuera de `tripsForLearning` | nuevo |
| Marcar una excepción y reconstruir cambia la cifra; desmarcarla la devuelve | nuevo |
| Sin responder cuenta como normal, la cifra no cambia | nuevo |
| El `TripOutcome` de un cierre automático se guarda como pendiente | extender `trip_conclusions_test.dart` |
| El reclamo del servicio pide tipo location durante el armado | extender `foreground_service_test.dart` |
| `autoTripEvents` tiene un oyente y emite arranque y cierre | extender `trip_autostart_test.dart` |

### 5.2 En el teléfono, que ningún test cubre

Lista de comprobación de un viaje real: conectar, apagar la pantalla, guardar el
teléfono, rodar, volver.

1. El viaje arrancó solo, sin tocar nada.
2. La notificación dice "Grabando viaje" en español, con distancia que avanza.
3. Al llegar y quedarse quieto 3 minutos, se cerró solo.
4. La notificación dice que el viaje se guardó, con km y Wh/km.
5. Al abrir la app aparece el resumen del viaje.
6. Si movió el número más del 5%, aparece la pregunta.
7. Responder "fue una excepción" devuelve la autonomía al valor anterior.

---

## 6. Fuera de alcance, para otro momento

Anotados acá para no perderlos:

- Limpieza de las opciones: "empezar viajes solo" cierra viajes y el título solo
  promete empezar; "seguir leyendo con la pantalla apagada" ya viene encendido y
  explica el mecanismo de Android en lugar de la consecuencia; "vigilar la
  carga" está detrás de Pro pero el switch gratuito de arriba ya sostiene el
  mismo servicio, así que la puerta de Pro está sorteada.
- Agrupamiento de los avisos: 17 códigos en una lista plana ordenada solo por
  gravedad, que son cuatro familias (desbalance 6, capacidad 6, autonomía 2,
  sueltos 3). Una historia se parte porque la consecuencia queda lejos de su
  causa.
- Decaimiento por tiempo del aprendizaje.
- El número en vivo optimista durante el viaje.
- Normalización por contexto (pendiente, velocidad, temperatura).
