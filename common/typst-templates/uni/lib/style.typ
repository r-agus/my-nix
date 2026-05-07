#import calc: rem
#let setup(
  body,
  course,
  author,
  title,
) = {
  set page(
    header-ascent: 15%,
    footer-descent: 12%,

    header: context {
      let (p,) = counter(page).get()
      let phys_page = here().page()

      let even = rem(p, 2) == 0
      let headings = query(selector(heading.where(level: 1)))
      let active_heading = headings.rev().find(h => h.location().page() <= phys_page)
      let chapter = if active_heading != none { active_heading.body } else { "" }

      let left_text  = if even { course } else { chapter }
      let right_text = if even { author } else { title }

      set text(size: 9pt, fill: gray)

      stack(
        spacing: 3pt,
        grid(
          columns: (1fr, 1fr),
          align: (left, right),
          left_text,
          right_text,
        ),
        line(length: 100%, stroke: 0.25pt + gray),
      )
    },

    footer: context {
      set text(size: 9pt, fill: gray)
         align(center)[#counter(page).display()]
    },
  )

  show figure.where(kind: table): set figure.caption(position: top)

  body
}
