// counter to track the number of algo and code elements
// used as an id when accessing:
//   _algo-comment-lists
//   _algo-page-break-lines
#let _algo-id-ckey = "_algo-id"

// counter to track the current indent level in an algo element
#let _algo-indent-ckey = "_algo-indent"

// counter to track the number of lines in an algo element
#let _algo-line-ckey = "_algo-line"

// state value to track whether the current context is an algo element
#let _algo-in-algo-context = state("_algo-in-algo-context", false)

// state value to mark the page that each line of an
//   algo or code element appears on
#let _algo-current-page = state("_algo-current-page", 1)

// state value for storing algo comments
// dictionary that maps algo ids (as strings) to a dictionary that maps
//   line indexes (as strings) to the comment appearing on that line
#let _algo-comment-lists = state("_algo-comment-lists", (:))

// state value for storing pagebreak occurrences in algo or code elements
// dictionary that maps algo/code ids (as strings) to a list of integers,
//   where each integer denotes a 0-indexed line that appears immediately
//   after a page break
#let _algo-pagebreak-line-indexes = state("_algo-pagebreak-line-indexes", (:))

// list of default keywords that will be highlighted by strong-keywords
#let _algo-default-keywords = (
  "if",
  "else",
  "then",
  "while",
  "for",
  "do",
  ":",
  "end",
  "and",
  "or",
  "not",
  "in",
  "to",
  "down",
  "let",
  "return",
  "goto",
)


// Get the thickness of a stroke.
// Credit to PgBiel on GitHub.
#let _stroke-thickness(stroke) = {
  if type(stroke) in ("length", "relative length") {
    stroke
  } else if type(stroke) == "color" {
    1pt
  } else if type(stroke) == "stroke" {
    let r = regex("^\\d+(?:em|pt|cm|in|%)")
    let s = repr(stroke).find(r)

    if s == none {
      1pt
    } else {
      eval(s)
    }
  } else if type(stroke) == "dictionary" and "thickness" in stroke {
    stroke.thickness
  } else {
    1pt
  }
}


// Given data about a line in an algo or code, creates the
//   indent guides that should appear on that line.
//
// Parameters:
//   stroke: Stroke for drawing indent guides.
//   indent-level: The indent level on the given line.
//   indent-size: The length of a single indent.
//   content-height: The height of the content on the given line.
//   block-inset: The inset of the block containing all the lines.
//     Used when determining the length of an indent guide that appears
//     on the top or bottom of the block.
//   row-gutter: The gap between lines.
//     Used when determining the length of an indent guide that appears
//     next to other lines.
//   is-first-line: Whether the given line is the first line in the block.
//   is-last-line: Whether the given line is the last line in the block.
//     If so, the length of the indent guide will depend on block-inset.
//   is-before-page-break: Whether the given line is just before a page break.
//     If so, the length of the indent guide will depend on block-inset.
//   is-after-page-break. Whether the given line is just after a page break.
//     If so, the length of the indent guide will depend on block-inset.
#let _indent-guides(
  stroke,
  indent-level,
  indent-size,
  content-height,
  block-inset,
  row-gutter,
  is-first-line,
  is-last-line,
  is-before-pagebreak,
  is-after-pagebreak,
) = {
  let stroke-width = _stroke-thickness(stroke)

  style(styles => {
    // converting input parameters to absolute lengths
    let content-height-pt = measure(
      rect(width: content-height),
      styles
    ).width

    let inset-pt = measure(
      rect(width: block-inset),
      styles
    ).width

    let row-gutter-pt = measure(
      rect(width: row-gutter),
      styles
    ).width

    // heuristically determine the height of the containing table cell
    let text-height = measure(
      [ABCDEFGHIJKLMNOPQRSTUVWXYZ],
      styles
    ).height

    let cell-height = calc.max(content-height-pt, text-height)

    // lines are drawn relative to the top left of the bounding box for text
    // backset determines how far up the starting point should be moved
    let backset = if is-first-line {
      0pt
    } else if is-after-pagebreak {
      calc.min(inset-pt, row-gutter-pt) / 2
    } else {
      row-gutter-pt / 2
    }

    // determine how far the line should extend
    let stroke-length = backset + cell-height + (
      if is-last-line {
        calc.min(inset-pt / 2, cell-height / 4)
      } else if is-before-pagebreak {
        calc.min(inset-pt, row-gutter-pt) / 2
      } else {
        row-gutter-pt / 2
      }
    )

    // draw the indent guide for each indent level on the given line
    for j in range(indent-level) {
      place(
        dx: indent-size * j + stroke-width / 2 + 0.5pt,
        dy: -backset,
        line(
          length: stroke-length,
          angle: 90deg,
          stroke: stroke
        )
      )
    }
  })
}


// Creates the indent guides for a given line while updating relevant state.
// Updates state for:
//   _algo-current-page
//   _algo-pagebreak-line-indexes
//
// Parameters:
//   indent-guides: Stroke for drawing indent guides.
//   content: The content that appears on the given line.
//   line-index: The 0-based index of the given line.
//   num-lines: The total number of lines in the current algo/code element.
//   indent-level: The indent level at the given line.
//   indent-size: The indent size used in the current algo/code element.
//   block-inset: The inset of the current algo/code element.
//   row-gutter: The row-gutter of the current algo/code element.
#let _build-indent-guides(
  indent-guides,
  content,
  line-index,
  num-lines,
  indent-level,
  indent-size,
  block-inset,
  row-gutter
) = {
  locate(loc => style(styles => {
    let curr-page = loc.page()
    let prev-page = _algo-current-page.at(loc)
    let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
    let pagebreak-index-lists = _algo-pagebreak-line-indexes.final(loc)

    let content-height = measure(content, styles).height
    let is-first-line = line-index == 0
    let is-last-line = line-index == num-lines - 1
    let is-before-pagebreak = (
      id-str in pagebreak-index-lists and
      pagebreak-index-lists.at(id-str).contains(line-index + 1)
    )
    let is-after-pagebreak = prev-page != curr-page

    // display indent guides at the current line
    _indent-guides(
      indent-guides,
      indent-level,
      indent-size,
      content-height,
      block-inset,
      row-gutter,
      is-first-line,
      is-last-line,
      is-before-pagebreak,
      is-after-pagebreak,
    )

    // state updates
    if is-after-pagebreak {
      // update pagebreak-lists to include the current line index
      _algo-pagebreak-line-indexes.update(index-lists => {
        let indexes = if id-str in index-lists {
          index-lists.at(id-str)
        } else {
          ()
        }

        indexes.push(line-index)
        index-lists.insert(id-str, indexes)
        index-lists
      })
    }

    _algo-current-page.update(curr-page)
  }))
}


// Asserts that the current context is an algo element.
// Returns the provided message if the assertion fails.
#let _assert-in-algo(message) = {
  _algo-in-algo-context.display(is-in-algo => {
    assert(is-in-algo, message: message)
  })
}


// Increases indent in an algo element.
// All uses of #i within a line will be
//   applied to the next line.
#let i = {
  _assert-in-algo("cannot use #i outside an algo element")
  counter(_algo-indent-ckey).step()
}


// Decreases indent in an algo element.
// All uses of #d within a line will be
//   applied to the next line.
#let d = {
  _assert-in-algo("cannot use #d outside an algo element")

  counter(_algo-indent-ckey).update(n => {
    assert(n - 1 >= 0, message: "dedented too much")
    n - 1
  })
}


// Adds a comment to a line in an algo body.
//
// Parameters:
//   body: Comment content.
#let comment(body) = {
  _assert-in-algo("cannot use #comment outside an algo element")

  locate(loc => {
    let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
    let line-index-str = str(counter(_algo-line-ckey).at(loc).at(0))

    _algo-comment-lists.update(comment-lists => {
      let comments = if id-str in comment-lists {
        comment-lists.at(id-str)
      } else {
        (:)
      }

      let ongoing-comment = if line-index-str in comments {
        comments.at(line-index-str)
      } else {
        []
      }

      let comment-content = ongoing-comment + body
      comments.insert(line-index-str, comment-content)
      comment-lists.insert(id-str, comments)
      comment-lists
    })
  })
}


// Displays an algorithm in a block element.
//
// Parameters:
//   body: Algorithm content.
//   title: Algorithm title.
//   Parameters: Array of parameters.
//   line-numbers: Whether to have line numbers.
//   strong-keywords: Whether to have bold keywords.
//   keywords: List of terms to receive strong emphasis if
//     strong-keywords is true.
//   comment-prefix: Content to prepend comments with.
//   comment-color: Font color for comments.
//   indent-size: Size of line indentations.
//   indent-guides: Stroke for indent guides.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
#let algo(
  body,
  title: none,
  parameters: (),
  line-numbers: true,
  strong-keywords: false,
  keywords: _algo-default-keywords,
  comment-prefix: "// ",
  comment-color: rgb(45%, 45%, 45%),
  indent-size: 20pt,
  indent-guides: none,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  counter(_algo-id-ckey).step()
  counter(_algo-line-ckey).update(0)
  counter(_algo-indent-ckey).update(0)
  _algo-in-algo-context.update(true)

  locate(
    loc => _algo-current-page.update(loc.page())
  )

  // convert keywords to content values
  keywords = keywords.map(e => {
    if type(e) == "string" {
      [#e]
    } else {
      e
    }
  })

  // concatenate consecutive non-whitespace elements
  // i.e. just combine everything that definitely aren't on separate lines
  let text-and-whitespaces = {
    let joined-children = ()
    let temp = []

    for child in body.children {
      if (
        child == [ ]
        or child == linebreak()
        or child == parbreak()
      ){
        if temp != [] {
          joined-children.push(temp)
          temp = []
        }

        joined-children.push(child)
      } else {
        temp += child
      }
    }

    if temp != [] {
      joined-children.push(temp)
    }

    joined-children
  }

  // filter out non-meaningful whitespace elements
  let text-and-breaks = text-and-whitespaces.filter(
    elem => elem != [ ] and elem != parbreak()
  )

  // handling meaningful whitespace
  // make final list of empty and non-empty lines
  let lines = {
    let joined-lines = ()
    let line-parts = []
    let num-linebreaks = 0

    for line in text-and-breaks {
      if line == linebreak() {
        if line-parts != [] {
          joined-lines.push(line-parts)
          line-parts = []
        }

        num-linebreaks += 1

        if num-linebreaks > 1 {
          joined-lines.push([])
        }
      } else {
        line-parts += [#line ]
        num-linebreaks = 0
      }
    }

    if line-parts != [] {
      joined-lines.push(line-parts)
    }

    joined-lines
  }

  // build text, comment lists, and indent-guides
  let algo-steps = ()

  for (i, line) in lines.enumerate() {
    let formatted-line = {
      // bold keywords
      show regex("\S+"): it => {
        if strong-keywords and it in keywords {
          strong(it)
        } else {
          it
        }
      }

      counter(_algo-indent-ckey).display(indent-level => {
        if indent-guides != none {
          _build-indent-guides(
            indent-guides,
            line,
            i,
            lines.len(),
            indent-level,
            indent-size,
            inset,
            row-gutter
          )
        }

        pad(
          left: indent-size * indent-level,
          line
        )
      })

      counter(_algo-line-ckey).step()
    }

    algo-steps.push(formatted-line)
  }

  // build algorithm header
  let algo-header = {
    set align(left)

    if title != none {
      set text(1.1em)

      if type(title) == "string" {
        underline(smallcaps(title))
      } else {
        title
      }

      if parameters.len() == 0 {
        $()$
      }
    }

    if parameters != () {
      set text(1.1em)

      $($

      for (i, param) in parameters.enumerate() {
        if type(param) == "string" {
          math.italic(param)
        } else {
          param
        }

        if i < parameters.len() - 1 {
          [, ]
        }
      }

      $)$
    }

    if title != none or parameters != () {
      [:]
    }
  }

  // build table
  let algo-table = locate(loc => {
    let id-str = str(counter(_algo-id-ckey).at(loc).at(0))
    let comment-lists = _algo-comment-lists.final(loc)
    let has-comments = comment-lists.keys().contains(id-str)

    let comment-contents = if has-comments {
      let comments = comment-lists.at(id-str)

      range(algo-steps.len()).map(i => {
        let index-str = str(i)

        if index-str in comments {
          comments.at(index-str)
        } else {
          none
        }
      })
    } else {
      none
    }

    let num-columns = 1 + int(line-numbers) + int(has-comments)

    let align = {
      let alignments = ()

      if line-numbers {
        alignments.push(right + horizon)
      }

      alignments.push(left)

      if has-comments {
        alignments.push(left + horizon)
      }

      (x, _) => alignments.at(x)
    }

    let table-data = ()

    for (i, line) in algo-steps.enumerate() {
      if line-numbers {
        let line-number = i + 1
        table-data.push(str(line-number))
      }

      table-data.push(line)

      if has-comments {
        if comment-contents.at(i) == none {
          table-data.push([])
        } else {
          table-data.push({
            set text(fill: comment-color)
            comment-prefix
            comment-contents.at(i)
          })
        }
      }
    }

    table(
      columns: num-columns,
      column-gutter: column-gutter,
      row-gutter: row-gutter,
      align: align,
      stroke: none,
      inset: 0pt,
      ..table-data
    )
  })

  // display content
  set par(justify: false)
  align(center, block(
    width: auto,
    height: auto,
    fill: fill,
    stroke: stroke,
    inset: inset,
    outset: 0pt,
    breakable: true
  )[
    #algo-header
    #v(weak: true, row-gutter)
    #align(left, algo-table)
  ])

  _algo-in-algo-context.update(false)
}


// Displays code in a block element.
// Credit to Dherse on GitHub for the code
//   to display raw text with line numbers.
//
// Parameters:
//   body: Raw text.
//   line-numbers. Whether to have line numbers.
//   indent-guides: Stroke for indent guides.
//   tab-size: Amount of spaces that should be considered an indent.
//     Set to none if you intend to use tab characters.
//   row-gutter: Space between lines.
//   column-gutter: Space between line numbers and text.
//   inset: Inner padding.
//   fill: Fill color.
//   stroke: Border stroke.
#let code(
  body,
  line-numbers: true,
  indent-guides: none,
  tab-size: 2,
  row-gutter: 10pt,
  column-gutter: 10pt,
  inset: 10pt,
  fill: rgb(98%, 98%, 98%),
  stroke: 1pt + rgb(50%, 50%, 50%)
) = {
  counter(_algo-id-ckey).step()
  locate(
    loc => _algo-current-page.update(loc.page())
  )

  let table-data = ()
  let raw-children = body.children.filter(e => e.func() == raw)
  let lines-by-child = raw-children.map(e => e.text.split("\n"))
  let num-lines = lines-by-child.map(e => e.len()).sum()
  let line-index = 0

  for (i, lines) in lines-by-child.enumerate() {
    for line in lines {
      if line-numbers {
        table-data.push(str(line-index + 1))
      }

      let content = {
        let raw-line = raw(line, lang: raw-children.at(i).lang)

        if indent-guides != none {
          style(styles => {
            let (indent-level, indent-size) = if tab-size == none {
              let whitespace = line.match(regex("^(\t*).*$"))
                                    .at("captures")
                                    .at(0)
              (
                whitespace.len(),
                measure(raw("\t"), styles).width
              )
            } else {
              let whitespace = line.match(regex("^( *).*$"))
                                    .at("captures")
                                    .at(0)
              (
                calc.floor(whitespace.len() / tab-size),
                measure(raw("a" * tab-size), styles).width
              )
            }

            _build-indent-guides(
              indent-guides,
              raw-line,
              line-index,
              lines.len(),
              indent-level,
              indent-size,
              inset,
              row-gutter
            )
          })
        }

        raw-line
      }

      table-data.push(content)
      line-index += 1
    }
  }

  // display content
  set par(justify: false)
  align(center, block(
    stroke: stroke,
    inset: inset,
    fill: fill,
    width: auto,
    breakable: true
  )[
    #table(
      columns: if line-numbers {2} else {1},
      inset: 0pt,
      stroke: none,
      fill: none,
      row-gutter: row-gutter,
      column-gutter: column-gutter,
      align: if line-numbers {
        (x, _) => (right+horizon, left).at(x)
      } else {
        left
      },
      ..table-data
    )
  ])
}
