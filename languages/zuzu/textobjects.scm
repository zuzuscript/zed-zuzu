(function_declaration
  body: (block) @function.inside) @function.around

(function_expression
  body: (block) @function.inside) @function.around

(method_declaration
  body: (block) @function.inside) @function.around

(class_declaration
  body: (class_body) @class.inside) @class.around

(trait_declaration
  body: (trait_body) @class.inside) @class.around

(comment)+ @comment.around
(pod_block) @comment.around
