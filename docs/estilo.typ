#set page(
  paper: "a4",
  margin: (top: 22mm, bottom: 22mm, left: 22mm, right: 22mm),
  numbering: "1",
)
#set text(font: "Times New Roman", size: 10.5pt, lang: "es", fill: black)
#set par(justify: false, leading: 0.55em, spacing: 0.75em)
#set heading(numbering: none)
#show heading.where(level: 1): set text(size: 13.5pt, weight: "bold", fill: black)
#show heading.where(level: 1): set block(above: 1.4em, below: 0.65em)
#show heading.where(level: 2): set text(size: 11.5pt, weight: "bold", fill: black)
#show heading.where(level: 2): set block(above: 1.15em, below: 0.5em)
#show heading.where(level: 3): set text(size: 10.5pt, weight: "bold", fill: black)
#show heading.where(level: 1): it => {
  if it.body == [Reproducción del experimento] { pagebreak(weak: true) }
  it
}
#show raw: set text(font: "Menlo", size: 8.5pt, fill: black)
#set raw(theme: none)
#show raw.where(block: true): set block(inset: (x: 6pt, y: 5pt), stroke: (left: 0.7pt + luma(160)), width: 100%)
#show figure: set block(breakable: false, spacing: 0.9em)
#show table: set text(size: 9.5pt, fill: black)
#show table.cell: it => {
  if it.align == auto { align(left, it) } else { it }
}
#show table.cell.where(y: 0): strong
#set table(
  inset: (x: 6pt, y: 4.5pt),
  stroke: (_, y) => (
    top: if y == 0 { 0.7pt + black } else if y == 1 { 0.5pt + black } else { none },
    bottom: 0.35pt + luma(190),
  ),
)
#show link: set text(fill: black)
#show regex("s\\. f\\.-[ab]"): it => box(it)

// APA reference list: hanging indent, double spacing, centered section label.
#let apa-references(body) = {
  set text(top-edge: 0.8em, bottom-edge: 0.2em)
  set par(hanging-indent: 0.5in, leading: 1em, spacing: 1em)
  show heading: it => {
    set par(hanging-indent: 0pt)
    block(width: 100%, above: 0pt, below: 1em, align(center, strong(it.body)))
  }
  body
}
