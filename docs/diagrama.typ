#let flujo = {
  let nodo(t) = box(stroke: 0.65pt, inset: 6pt, radius: 2pt, t)
  align(center)[
    #nodo[Vehículo / k6] $arrow.r$ #nodo[HTTP · validar evento] $arrow.r$ #nodo[SQLite · guardar]
    #linebreak()
    #v(5pt)
    #text(style: "italic")[El evento Emergency queda pendiente en la misma fila.]
    #linebreak()
    #v(5pt)
    #nodo[SQLite · pendientes] $arrow.r$ #nodo[Trabajador] $arrow.r$ #nodo[API de Gmail] $arrow.r$ #nodo[Buzón]
    #linebreak()
    #text(style: "italic")[En el ensayo, el trabajador entrega el aviso a un receptor SMTP local.]

  ]
}
