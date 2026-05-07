#import "@preview/acrostiche:0.7.0": *

#import "lib/style.typ": setup
#import "cover.typ": cover
#import "acronym.typ": acronyms

#let doc_title = "<Title>"
#let authors_portrait = ("Rubén Agustín",)
#let authors_header = "Rubén Agustín"
#let course = "<Course>"
#let date = "<Date>"

#show heading: set block(above: 1.2em, below: 1em)
#set heading(numbering: "1.")

#set par(justify: true)

#set figure(supplement: [Figura])

#cover(title: doc_title, course: course, authors: authors_portrait, date: date, img_path: "img/cover.png")
#pagebreak()

#show: doc => setup(
  doc,
  course,
  authors_header,
  doc_title,
)

#set page(numbering: "I")

#outline()
#pagebreak()
#outline(title: "Table of Figures", target: figure.where(kind: image))
#pagebreak()
#outline(title: "Table of Tables", target: figure.where(kind: table))
#init-acronyms(acronyms)
#pagebreak()
#print-index(sorted: "up", title: "Table of Acronyms")

#set page(numbering: "1")
#counter(page).update(1)

#include "chap/placeholder.typ"
