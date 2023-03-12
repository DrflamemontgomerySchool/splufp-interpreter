class __splufp__function {
  #value;
  constructor(value) {
    if(typeof(value) == 'function') {
      if(value.length > 0) {
        this.value = function() { return value };
        return;
      }
    }
    this.value = value;
  }

  call() {
    if(typeof(this.value) == "function") {
      return this.value();
    }
    return this.value;
  }
}

class __splufp__function_assignable {
  #value;
  constructor(value) {
    if(typeof(value) == 'function') {
      if(value.length > 0) {
        this.value = function() { return value };
        return;
      }
    }
    this.value = value;
  }

  call() {
    if(typeof(this.value) == "function") {
      return this.value();
    }
    return this.value;
  }

  set_value(value) {
    this.value = value;
  }
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

function delay(ms) {
  var now = new Date().getTime();
  while(new Date().getTime() < now + ms){ /* Do nothing */ }
}
