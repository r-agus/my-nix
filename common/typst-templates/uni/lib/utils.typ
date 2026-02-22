#let imgcell(path, cap: none) = {
  stack(
    spacing: 2pt,
    image(path, width: 100%, fit: "cover"),
    if cap != none { text(size: 9pt, cap) }
  )
}
