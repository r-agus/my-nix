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

      let even = rem(p, 2) == 0
      let left_text  = if even { course } else { author }
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

  body
}
