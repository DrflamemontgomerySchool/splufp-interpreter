class __splufp__function {
  #value;
  constructor(value) {
    this.value = value;
  }

  call() {
    return this.value;
  }
}

class __splufp__function_assignable {
  #value;
  constructor(value) {
    this.value = value;
  }

  call() { return this.value; }

  set_value(value) {
    this.value = value;
  }
}

function add(a, b) {
  return a + b;
}

function sub(a, b) {
  return a - b;
}

function mul(a, b) {
  return a * b;
}

function div(a, b) {
  return a / b;
}

function neg(a) {
  return -a;
}

function obj_get(obj, name) {
  return obj[name];
}

function array_at(arr, n) {
  return arr[n];
}

function slice(arr, pos, end) {
  return arr.slice(pos, end);
}

function splice(arr, pos, len) {
  return arr.splice(pos, len);
}



function len(arr) {
  return arr.length;
}

function foldr(fn, init, arr) {
  if(arr.length > 1) {
    return foldr(fn, fn(new __splufp__function(init))(new __splufp__function(arr[0])), arr.slice(1, arr.length));
  }
  else if(arr.length > 0) {
    return fn(new __splufp__function(init))(new __splufp__function(arr[0]));
  }
  return init;
}

function foldl(fn, init, arr) {
  if(arr.length > 1) {
    return foldl(fn, fn(new __splufp__function(arr[0]))(new __splufp__function(init)), arr.slice(1, arr.length));
  }
  else if(arr.length > 0) {
    return fn(new __splufp__function(arr[0]))(new __splufp__function(init));
  }
  return init;
}

function map(fn, arr) {
  if(arr.length > 0) {
    fn(new __splufp__function(arr[0]));
    map(fn, arr.slice(1, arr.length));
  }
}

function log(str) {
  console.log(str);
}
