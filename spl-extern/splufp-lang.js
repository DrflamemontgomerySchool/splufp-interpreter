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
