-- Converts specific Pandoc fenced-div classes into LaTeX environments of the
-- same name when writing LaTeX/PDF, e.g. `::: {.concept}` becomes
-- \begin{concept}...\end{concept}. Pandoc does not do this automatically --
-- verified directly against the pandoc binary used by this build (3.10.1):
-- an unrecognized Div class is silently dropped from LaTeX output, with only
-- its content surviving. Other output formats (ePub/HTML) are unaffected by
-- this filter and keep the Div as a plain <div class="...">.
--
-- The environments themselves (colors, borders, spacing) are defined in
-- latex/callouts.tex, included separately via --include-in-header.

local supported = {
  concept = true,
}

function Div(el)
  if FORMAT:match("latex") and el.classes[1] and supported[el.classes[1]] then
    local env = el.classes[1]
    table.insert(el.content, 1, pandoc.RawBlock("latex", "\\begin{" .. env .. "}"))
    table.insert(el.content, pandoc.RawBlock("latex", "\\end{" .. env .. "}"))
    return el.content
  end
end
