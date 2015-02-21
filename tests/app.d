import unit_threaded.runner;

import std.stdio;

int main(string[] args) {
    return args.runTests!(
          "tests.hostlink", 
          "dolina.hostlink",
          "dolina.util",
          "dolina.dmrange"
          );
}
