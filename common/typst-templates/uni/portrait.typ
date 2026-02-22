#let portrait(title: "", course: "", authors: "", date: "", img_path: "") = [
  #set page(
    paper: "a4",
    margin: (top: 18mm, bottom: 18mm, left: 20mm, right: 20mm),
    numbering: none,
  )

  #set text(font: "Libertinus Serif", size: 11pt)

  #let uni = "Universidad Carlos III de Madrid"
  #let subtitle = course
  #let authors = authors

  #let date = date

  #let logo_path = "img/Logo_UC3M.png"

  #box(width: 100%, height: 100%)[
    #align(center)[
      #stack(
        spacing: 0pt,

        image(logo_path, width: 50mm),

        v(10mm),

        text(
          size: 15pt,
          tracking: 2.2pt,
          uni,
        ),

        v(22mm),

        text(size: 20pt, weight: "bold", title),
        v(4mm),
        text(size: 11pt, subtitle),

        v(15mm),
        if img_path != "" { image(img_path, width: 60%, fit: "cover") },
        v(1fr),

        stack(
          spacing: 2mm,
          ..authors.map(a => text(size: 10.5pt, a)),
        ),


        v(5mm),
        text(size: 10pt, date),
      )
    ]
  ]
]
