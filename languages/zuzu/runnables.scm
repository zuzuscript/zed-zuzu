((source_file
  (shebang) @run)
  (#set! tag zuzu-script))

((function_declaration
  name: (identifier) @run @function
  (#eq? @function "__main__"))
  (#set! tag zuzu-entrypoint))

((expression_statement
  (call_expression
    function: (identifier) @run
    arguments: (argument_list))
  (#eq? @run "plan"))
  (#set! tag zuzu-test))
