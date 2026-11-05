# Horizonte R: corrección de composición

La versión 2.32.0 conservó demasiadas tarjetas y distribuciones anteriores. Esta corrección traslada la jerarquía y los instrumentos de [la propuesta R aprobada](horizonte-r-proposal.html) a los widgets de Flutter.

| Vista | Cambio de composición |
| --- | --- |
| Ahora | Autonomía protagonista, segmentos de carga arriba, SOC lateral, franja abierta de potencia/temperatura/voltaje y acceso destacado al viaje. La autonomía con carga completa conserva su propia procedencia. |
| Viaje | Velocímetro con trazos laterales, distancia y tiempo agrupados, autonomía/SOC y telemetría abierta. Los controles se apilan con texto grande. |
| Batería | Delta y promedio abiertos; matriz de celdas más compacta, conservando extremos, balanceo y resistencias disponibles. |
| Salud | Instrumento de salud y capacidad, con distinción visible entre salud medida y reportada. Las explicaciones largas quedan disponibles mediante información. |
| Historial | Totales con jerarquía de instrumento; distancia protagonista en cada viaje y consumo secundario. Se conservan detalle, filtros y confirmación de borrado. |
| Cierre y detalle | Distancia y consumo asimétricos; terreno con tres lecturas y una barra proporcional al perfil real; tiempos compactos y carga al salir → al llegar. |
| Ajustes | Apariencia visible y categorías navegables. Los controles originales siguen dentro de sus categorías; alertas y estado del BMS continúan actualizándose con la pantalla abierta. |
| Vistas secundarias | Secciones abiertas con encabezados y separadores; menos paneles anidados. Los controles específicos conservan su comportamiento. |

## Datos y comportamiento conservados

- Cuesta arriba, llano y cuesta abajo proceden del recorrido almacenado; sin recorrido se muestran como no disponibles.
- Tiempos, velocidades, energía usada/recuperada/neta, SOC gastado, voltajes, corriente, temperatura, delta, resistencia y aprendizaje permanecen accesibles.
- Una medición ausente conserva su estado de ausencia. La autonomía actual y la autonomía con carga completa siguen usando sus cálculos y fuentes independientes.
- La apariencia Sistema/Claro/Oscuro continúa persistida.
- Los valores grandes se mantienen en una sola lectura al 200 % de texto; las unidades pueden pasar a la línea siguiente.
- No se añaden saludos, celebraciones ni textos de cierre sin información.

## Evidencia visual

Las imágenes siguientes son capturas del renderizador de pruebas de widgets de Flutter, con fuentes cargadas y datos de prueba. No son otro prototipo HTML ni evidencia de ejecución en un teléfono o emulador. El HTML de revisión solo presenta estas imágenes.

La captura normal usa 390 × 844 dp; las pruebas visuales con texto al 200 % usan 320 × 1000 dp. Los PNG se exportan a escala 2.

| Vista | Oscuro | Claro |
| --- | --- | --- |
| Ahora, con historial de prueba | [Captura](horizonte-r-fidelity-evidence/now-dark.png) | [Captura](horizonte-r-fidelity-evidence/now-light.png) |
| Ahora, sin aprendizaje, para comparar la misma lectura anterior | [Captura](horizonte-r-fidelity-evidence/now-unlearned-dark.png) | [Captura](horizonte-r-fidelity-evidence/now-unlearned-light.png) |
| Viaje en grabación | [Captura](horizonte-r-fidelity-evidence/ride-dark.png) | [Captura](horizonte-r-fidelity-evidence/ride-light.png) |
| Celdas | [Captura](horizonte-r-fidelity-evidence/cells-dark.png) | [Captura](horizonte-r-fidelity-evidence/cells-light.png) |
| Térmico | [Captura](horizonte-r-fidelity-evidence/thermal-dark.png) | [Captura](horizonte-r-fidelity-evidence/thermal-light.png) |
| Historial | [Captura](horizonte-r-fidelity-evidence/history-dark.png) | [Captura](horizonte-r-fidelity-evidence/history-light.png) |
| Salud | [Captura](horizonte-r-fidelity-evidence/health-dark.png) | [Captura](horizonte-r-fidelity-evidence/health-light.png) |
| Cierre | [Captura](horizonte-r-fidelity-evidence/summary-dark.png) | [Captura](horizonte-r-fidelity-evidence/summary-light.png) |
| Ajustes | [Captura](horizonte-r-fidelity-evidence/settings-dark.png) | [Captura](horizonte-r-fidelity-evidence/settings-light.png) |

Texto al 200 %: [Ahora](horizonte-r-fidelity-evidence/now-large-text.png), [Viaje](horizonte-r-fidelity-evidence/ride-large-text.png), [Cierre](horizonte-r-fidelity-evidence/summary-large-text.png).

La comparación anterior usa los PNG ya publicados en [horizonte-r-evidence](horizonte-r-evidence), conservados sin modificar. En Ahora se compara el estado sin aprendizaje de ambos diseños; en Cierre se usa el mismo viaje de 12,8 km.

## Validación

La suite completa terminó con **1.580 pruebas aprobadas**. El análisis estático general y el análisis final de los instrumentos, la pantalla de viaje y las pruebas nuevas no reportaron incidencias. La ejecución adicional de captura y lecturas completas aprobó sus seis comprobaciones.

El [manifiesto](horizonte-r-fidelity-evidence/manifest.json) identifica el código capturado, los datos de prueba, los hashes de las imágenes y el resultado de las verificaciones locales. Registra el estado previo a la publicación. La corrección se prepara como **v2.32.1**, build base **2079**. La aceptación visual en Android físico permanece pendiente.
