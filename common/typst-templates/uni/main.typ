#import "lib/style.typ": setup
#import "cover.typ": cover

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

#include "chap/placeholder.typ"
