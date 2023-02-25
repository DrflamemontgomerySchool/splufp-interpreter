# My Language
## What is my language

My language is dynamically typed function programming language \
Everything is a function including variables \
Currying is supported by default \
Lambdas are supported by default \
Everything is a constant unless specified by the keyword 'let'\
functions return the last statement \

## Data Types
- [x] Null
- [x] Bool
- [x] String
- [x] Number (floats and integers are the same)
- [x] Array
- [x] Function
- [x] JS Function (Allows a javascript function to be used in splufp)
- [x] Object (denoted by {})
- [ ] Macro
- [x] Lambda

### Data Type Examples

```haskell

let this_is_a_null = null
let this_is_a_bool = false
let this_is_a_bool = true
let this_is_a_string = "A string"
let this_is_a_number = -1
let this_is_a_number = 9
let this_is_a_number = -1.0
let this_is_a_number = 576.12371
let this_is_a_array = [1, 2, 3, 4, 5]
this_is_a_function a b c { a + b + c }
externjs this_is_a_js_function a b
let this_is_a_object = { a : 2, b : 11 }
let this_is_a_lambda = \(x y\) { add x y }
```

### How to declare variables and functions

``` haskell

-- Declaring variables
variable_name = 4

-- Functions are similar but have an arguments list
function_name arg1 arg2 { add arg1 arg2 }

-- Variables can be constant or modifiable
set var_or_func = 12
var_of_func = 10

let const_var = 10 -- Declare 'const_var' with a value of 10 
const_var = 12 -- Tries to reassign value to 'const_var' but this throws a runtime error

-- Binding to a javascript function is simple, you just have to have the same function profile
externjs js_function a b

-- Macros are useful for generating code and are simple to create
macro macro_function a b = add a b

test_func a {
  macro_function a 7
}
-- generated code
-- test_func a = {
--   add a 7
-- }

-- Macros can also parse non-data-types
macro adder_macro name value =
  ##name##_##value## a {\
    a + value\
}

adder_macro func_that_adds 4
-- generated code
-- func_that_adds_4 a = {
--   a + 4
-- }
```

## Currying

```haskell
-- Profile of 'function_name'
-- function_name arg1 arg2 arg3 arg4


-- returns a function with profile of 'function arg3 arg4'
function_name 1 2
```

## Example of Project Transpile

Input:

```haskell
let variable = 5

func a b c d = {
  [a, b, c, d]
}
  
main {
  let b = func 1 2 3
  log (b 1)
  0
}
```

Ouput: 

```javascript

var __spl__variable = new __splufp__function(5);

var __spl__func = new __splufp_function(
  function(__spl__a) {
    return function(__spl__b) {
      return function(__spl__c) {
        return function(__spl__d) {
          return new __splufp__function([__spl__a.call(), __spl__b.call(), __spl__c.call(), __spl__d.call()];
        }
      }
    }
  }
);

var __spl__main = function() {
  var __spl__b = new __splufp__function(
    __spl__func()(new __splufp__function(1))(new __splufp__function(2))(new __splufp__function(3));
  );
  __spl__log(__spl__b.call()(new __splufp__function(1)));
}

```
