; Keywords
[
  "as"
  "async"
  "await"
  "but"
  "case"
  "catch"
  "class"
  "const"
  "continue"
  "default"
  "do"
  "else"
  "extends"
  "for"
  "from"
  "function"
  "if"
  "import"
  "in"
  "last"
  "let"
  "method"
  "new"
  "next"
  "return"
  "spawn"
  "static"
  "switch"
  "throw"
  "trait"
  "try"
  "unless"
  "weak"
  "while"
  "with"
] @keyword

[
  "say"
  "print"
  "warn"
  "assert"
  "debug"
] @function.builtin

(boolean) @boolean
(null) @constant.builtin

(magic_global) @constant.builtin
(self) @variable.builtin
(super) @variable.builtin
(placeholder) @variable.builtin

(comment) @comment
(shebang) @comment
(pod_block) @comment.documentation

(number) @number
(string) @string
(single_quoted_string) @string.byte
(triple_single_quoted_string) @string.byte
(template_string) @string.special
(template_fragment) @string.special
(regexp) @string.regex

(type_identifier) @type
(private_type_identifier) @type
(type_expression) @type

(identifier) @variable

(function_declaration
  name: (identifier) @function)

(method_declaration
  name: (identifier) @function.method)

(class_declaration
  name: (binding_identifier) @type.definition)

(trait_declaration
  name: (binding_identifier) @type.definition)

(parameter
  name: (binding_identifier) @variable.parameter)

(variable_declaration
  name: (binding_identifier) @variable)

(field_declaration
  name: (identifier) @property)

(import_specifier
  name: (_) @namespace)

(module_path) @namespace

(member_expression
  property: (identifier) @property)

(binary_expression
  operator: [
    "<<"
    ">>"
    "«"
    "»"
  ] @operator)

[
  ":="
  "~="
  "+="
  "-="
  "*="
  "×="
  "/="
  "÷="
  "**="
  "_="
  "?:="
  "?"
  "?:"
  "▷"
  "◁"
  "|>"
  "<|"
  "or"
  "⋁"
  "or?"
  "⋁?"
  "onlyif"
  "⊨"
  "onlyif?"
  "⊨?"
  "xor"
  "⊻"
  "xor?"
  "⊻?"
  "nor"
  "⊽"
  "nor?"
  "⊽?"
  "xnor"
  "↔"
  "xnor?"
  "↔?"
  "and"
  "⋀"
  "and?"
  "⋀?"
  "nand"
  "⊼"
  "nand?"
  "⊼?"
  "butnot"
  "⊭"
  "butnot?"
  "⊭?"
  "=="
  "≡"
  "!="
  "≢"
  "="
  "≠"
  "<"
  ">"
  "<="
  "≤"
  ">="
  "≥"
  "<=>"
  "≶"
  "≷"
  "∣"
  "divides"
  "∤"
  "eq"
  "ne"
  "gt"
  "ge"
  "lt"
  "le"
  "cmp"
  "eqi"
  "nei"
  "gti"
  "gei"
  "lti"
  "lei"
  "cmpi"
  "in"
  "∈"
  "∉"
  "subsetof"
  "⊂"
  "supersetof"
  "⊃"
  "equivalentof"
  "⊂⊃"
  "instanceof"
  "does"
  "can"
  "~"
  "@"
  "@?"
  "@@"
  "->"
  "→"
  "|"
  "^"
  "&"
  "union"
  "⋃"
  "intersection"
  "⋂"
  "\\"
  "∖"
  "_"
  "+"
  "-"
  "*"
  "/"
  "×"
  "÷"
  "mod"
  "**"
  "!"
  "¬"
  "not"
  "abs"
  "sqrt"
  "floor"
  "ceil"
  "round"
  "int"
  "uc"
  "lc"
  "length"
  "typeof"
  "++"
  "--"
] @operator

(set_literal
  [
    "<<"
    "«"
    (set_close)
    "»"
  ] @punctuation.bracket)

(bag_literal
  [
    "<<<"
    ">>>"
  ] @punctuation.bracket)

(pair_list_literal
  [
    "{{"
    "}}"
  ] @punctuation.bracket)

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
  "${"
  "⌊"
  "⌋"
  "⌈"
  "⌉"
] @punctuation.bracket

[
  ","
  ";"
  "."
  ":"
] @punctuation.delimiter

(pair_entry
  key: (bare_key) @string.special.symbol)

(pair_entry
  key: (bare_key
    (identifier) @string.special.symbol))

(pair_entry
  key: (bare_key
    (reserved_word_key) @string.special.symbol))

(pair_entry
  key: (bare_key
    (reserved_word_key
      [
        "async" "await" "do" "false" "function" "new" "null" "self"
        "spawn" "super" "true" "try"
        "not" "abs" "sqrt" "floor" "ceil" "round" "int" "uc" "lc"
        "length" "typeof"
      ] @string.special.symbol)))
